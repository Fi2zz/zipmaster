# ZipMaster — 设计文档（Spec）

- 日期：2026-10-16
- 状态：待评审
- 作者：协作设计（人 + agent）

## 1. 背景与目标

360压缩大师（`net.qihoo.www.360-zip`，v1.0.4，2022 构建）是一个 **仅 x86_64** 的 macOS 应用。
其压缩/解压内核实际是开源的 **p7zip**（`Resources/7z.dylib`）与 **unrar**（`Resources/Rar.dylib`），
上层是一个自研的 Objective-C/Cocoa 界面（约 91 个类）。

由于 Apple 计划在 macOS 28 起缩减 Rosetta 2 支持，Intel-only 应用将难以继续运行。
逆向该二进制为 arm64 不可行（无静态 x86_64→arm64 翻译器；界面无源码；RAR 许可禁止逆向）。
因此本项目选择：**从零构建一个原生 arm64 的 SwiftUI 应用，改用开源引擎自行编译**。

### 目标

1. 原生 arm64，可在 Apple 芯片（本机 Apple M5 / macOS 27）上构建并运行。
2. 提供基础的 **压缩** 与 **解压** 能力。
3. 格式覆盖尽量对齐 360压缩大师。
4. 开源项目：任何人可自行构建；本机 `scripts/build-app.sh` 一条命令产出可运行的 `.app`。
5. 引擎开源、可复现构建。

### 非目标（第一版不做）

- 密码 / 加密包
- 分卷 / 多卷压缩包（z01、r01 等）
- Finder 右键菜单 / Services / Quick Actions
- 包内文件列表与选择性解压
- 应用分发 / 公证 / Mac App Store 上架
- RAR **压缩**（专有算法，无法合法实现）

## 2. 技术选型

采用 **方案 A：打包命令行引擎（`7zz` + `unrar`，均原生 arm64），SwiftUI 通过 `Process` 调用**。

理由：格式覆盖度/工作量比最优。7-Zip 官方 CLI 单引擎即覆盖绝大多数格式，构建脚本编出两个 arm64 二进制即可。
（方案 B「引擎作为库链入」工程量大、7-Zip 仅 C++ 接口需自写桥接，列为后续演进；方案 C「纯 Swift 库」无法写 7z、读不了 rar5，覆盖不足。）

### 格式覆盖

| 格式 | 压缩（写） | 解压（读） | 引擎 |
|---|---|---|---|
| zip | ✅ | ✅ | 7zz |
| 7z | ✅ | ✅ | 7zz |
| tar | ✅ | ✅ | 7zz |
| gz | ✅ | ✅ | 7zz |
| bz2 | ✅ | ✅ | 7zz |
| xz | ✅ | ✅ | 7zz |
| rar / rar5 | ❌（专有） | ✅ | unrar（主）/ 7zz（备） |
| cab / iso / cpio / lzh / ar / rpm / wim | ❌ | ✅ | 7zz |

### 授权

- **7-Zip**：LGPL-2.1 + BSD-3-Clause + unRAR restriction。
- **unrar**：freeware 许可，允许用于解压；禁止用其重实现 RAR 压缩算法。
- 均需在 `LICENSES.md` 注明并随开源项目分发。

## 3. 项目结构

**形态**：SwiftPM 包 + 打包脚本（不提交 `.xcodeproj`）。Xcode 可直接打开 `Package.swift` 开发。

```
zipmaster/
├── Package.swift
├── Sources/ZipMaster/
│   ├── ZipMasterApp.swift        # @main，SwiftUI App
│   ├── Views/
│   │   ├── MainView.swift        # 主窗：压缩 / 解压两个入口
│   │   ├── ProgressView.swift    # 进度 + 取消
│   │   └── FormatPicker.swift
│   ├── Core/
│   │   ├── ArchiveEngine.swift   # protocol：create / extract
│   │   ├── SevenZipEngine.swift  # 调 7zz
│   │   ├── UnrarEngine.swift     # 调 unrar（仅 .rar）
│   │   ├── EngineLocator.swift   # 从 bundle 定位引擎二进制
│   │   └── ArchiveJob.swift      # ObservableObject：状态/进度/取消
│   └── Resources/Engines/        # 构建时放入 7zz、unrar（git 忽略产物）
├── scripts/
│   ├── build-engines.sh          # 拉源码 + 原生编译 arm64 引擎
│   └── build-app.sh              # swift build + 组装 .app + ad-hoc 签名
├── Tests/ZipMasterTests/
├── README.md
└── LICENSES.md
```

## 4. 引擎构建

`scripts/build-engines.sh`：

- **7-Zip**：clone `https://github.com/ip7z/7zip`，构建 `Alone2`（`7zz`）的 macOS arm64 目标，产出 `7zz`。
- **unrar**：下载 `unrarsrc`（RARLAB），`make -f makefile` 且加 `-D_MACOSX`，产出 `unrar`。
- **无需交叉编译**：在目标 Apple 芯片机器上原生编译，产物即为 arm64。
- 可选快捷路径：若检测到 Homebrew，允许 `brew install sevenzip unrar` 直接取二进制。
- 产物拷贝至 `Sources/ZipMaster/Resources/Engines/`。

`scripts/build-app.sh`：

1. 若引擎缺失，调用 `build-engines.sh`。
2. `swift build -c release`。
3. 组装 `ZipMaster.app`（`Contents/MacOS`、`Contents/Resources/Engines`、`Contents/Info.plist`）。
4. `codesign --force --deep -s -`（ad-hoc 签名），本机可直接运行。

## 5. 界面（基础版范围）

单窗口，两个操作：

- **解压**：选择/拖入一个压缩包 → 选择输出目录 → 解压全部；显示进度条与取消。
- **压缩**：选择/拖入多个文件或文件夹 → 选择格式（zip/7z/tar/gz/bz2/xz）→ 输出路径 → 压缩；显示进度条与取消。

支持拖拽。UI 语言：简体中文（后续可本地化）。

## 6. 引擎抽象与数据流

```swift
protocol ArchiveEngine {
    func extract(archive: URL, to destination: URL,
                 onProgress: @escaping (Double) -> Void) async throws
    func create(archive: URL, from sources: [URL], format: ArchiveFormat,
                onProgress: @escaping (Double) -> Void) async throws
}
```

- `SevenZipEngine`：`7zz x -bsp1 <archive> -o<dest>` 解压；压缩按格式选 `7z/zip/tar` 等；解析 stdout 百分比。
- `UnrarEngine`：`.rar` 时用 `unrar x -o+`。
- 一律通过 `Process.arguments` 以**参数数组**传递路径，绝不拼接 shell 字符串 —— 天然兼容空格/中文/emoji 路径。
- `ArchiveJob`（`ObservableObject`）：状态 `idle/running/succeeded/failed`、进度、取消（终止子进程）；后台队列执行，`@MainActor` 回传。
- `EngineLocator`：在 `Bundle.main` 的 `Resources/Engines/` 下定位二进制。

### 错误处理

- 子进程非零退出：捕获 stderr，弹出可读错误。
- 找不到引擎二进制：提示先运行 `scripts/build-engines.sh`。
- 输出路径已存在 / 无写权限：前置校验并给出明确提示。

## 7. 测试

- **单元测试**：各格式参数拼装、进度百分比解析、`EngineLocator` 定位逻辑。
- **集成测试**：用真实引擎建 zip/tar 再解出并校验内容；引擎不存在时跳过（`XCTSkip`）。
- **手动冒烟**：`./scripts/build-app.sh` → 打开 `ZipMaster.app`，跑一次压缩与一次解压。

## 8. 风险与开放问题

- 7-Zip 在 macOS arm64 上的确切 makefile 目标名需在实现时确认（`makefile.mac` / `makefile.mac_arm64`）。
- unrar 源码 URL / 版本需在实现时固定一个具体版本，保证可复现。
- `7zz` 进度格式可能随版本变化：解析需容错（解析失败时退化为不确定进度）。
- 首次运行可能触发 Gatekeeper：ad-hoc 签名的本机构建产物通常可直接运行；必要时在 README 说明 `xattr` 处理。
