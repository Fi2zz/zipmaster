# ZipMaster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从零构建一个原生 arm64 的 SwiftUI 压缩/解压应用，引擎改用开源 `7zz` + `unrar`，可在 Apple 芯片上自行构建运行，替代 Intel-only 的 360压缩大师。

**Architecture:** SwiftPM 可执行包 + 打包脚本组成 `.app`；SwiftUI 前端通过 `Process` 调用随包分发的 arm64 引擎二进制（`7zz` 覆盖 zip/7z/tar/gz/bz2/xz 及只读的 cab/iso/cpio/lzh 等，`unrar` 负责 rar 解压）。引擎经 `ArchiveEngine` 协议抽象，`ArchiveJob` 负责状态/进度/取消。

**Tech Stack:** Swift 6 / SwiftUI / SwiftPM；7-Zip (ip7z) 与 unrar (RARLAB) 源码在构建时原生编译为 arm64；XCTest。

**Spec:** `docs/superpowers/specs/2026-10-16-zipmaster-design.md`

## Global Constraints

- 目标平台：原生 arm64；在本机（Apple Silicon）原始编译引擎，**不做交叉编译**。
- 最低系统：macOS 13。
- 引擎：`7zz`（7-Zip `CPP/7zip/Bundles/Alone2`，`makefile.gcc`）+ `unrar`（`unrarsrc-7.3.1.tar.gz`），由 `scripts/build-engines.sh` 产出到 `Sources/ZipMaster/Resources/Engines/`。
- 路径一律通过 `Process.arguments` 数组传递，**禁止拼接 shell 字符串**。
- 基础版范围：不做密码/加密、不做分卷、不做 Finder 右键菜单、不做包内文件列表/选择性解压、**不做 RAR 压缩**。
- 应用名 `ZipMaster`；bundle id `com.example.zipmaster`；UI 语言简体中文；本机 ad-hoc 签名（不分发/不公证）。

## Review Focus

以下输入/失败模式 spec 隐含但任务测试需显式覆盖，按最可能出问题排序：

1. **路径含空格/中文/emoji** —— 必须能正确压缩/解压（Task 3、Task 4、Task 5 的集成测试用带空格与中文的文件名）。
2. **引擎二进制缺失** —— 应给出"请先运行 scripts/build-engines.sh"的明确错误，而非崩溃（Task 3）。
3. **目标文件已存在** —— 覆盖行为需确定（解压用 `-aoa`/`-o+` 覆盖），且在压缩覆盖输出时给出明确语义（Task 4、Task 5）。
4. **进度输出格式变化** —— 解析失败时退化为不确定进度而非报错（Task 7）。
5. **用户取消** —— 必须终止子进程并进入 `cancelled` 状态，不留下半成品错误（Task 8）。

---

### Task 1: SwiftPM 骨架与可运行 .app

**Files:**
- Create: `Package.swift`
- Create: `Sources/ZipMaster/ZipMasterApp.swift`
- Create: `Sources/ZipMaster/Views/MainView.swift`
- Create: `scripts/build-app.sh`
- Create: `.gitignore`（已存在，追加产物忽略）

**Interfaces:**
- Produces: 可执行的 `ZipMaster` target；`scripts/build-app.sh` 产出 `./ZipMaster.app`。

- [ ] **Step 1: 写 `Package.swift`**

`swift-tools-version:5.9`，`platforms: [.macOS(.v13)]`，executable target `ZipMaster`（路径 `Sources/ZipMaster`），test target `ZipMasterTests`。

- [ ] **Step 2: 写最小 SwiftUI App**

`ZipMasterApp.swift`：`@main struct ZipMasterApp: App { var body: some Scene { WindowGroup("ZipMaster") { MainView() } } }`。`MainView.swift`：`Text("ZipMaster")` 占位。

- [ ] **Step 3: 写 `scripts/build-app.sh`**

`set -euo pipefail`；`swift build -c release`；读取 `.build/release/ZipMaster` 二进制；组装 `ZipMaster.app/Contents/{MacOS,Resources}`；写 `Info.plist`（`CFBundleExecutable=ZipMaster`、`CFBundleIdentifier=com.example.zipmaster`、`LSMinimumSystemVersion=13.0`、`NSPrincipalClass=NSApplication`、`CFBundlePackageType=APPL`）；`codesign --force -s - ZipMaster.app`。

- [ ] **Step 4: 验证构建与启动**

Run: `chmod +x scripts/build-app.sh && ./scripts/build-app.sh && ls ZipMaster.app/Contents/MacOS/`
Expected: 打印 `ZipMaster`，无报错。
Run: `open ZipMaster.app`
Expected: 出现标题为 `ZipMaster` 的窗口。

- [ ] **Step 5: 提交**

```bash
git add Package.swift Sources/ZipMaster/ZipMasterApp.swift Sources/ZipMaster/Views/MainView.swift scripts/build-app.sh .gitignore
git commit -m "feat: scaffold SwiftPM app and .app packaging script"
```

---

### Task 2: 引擎构建脚本（7zz + unrar, arm64）

**Files:**
- Create: `scripts/build-engines.sh`
- Create: `Sources/ZipMaster/Resources/Engines/.gitkeep`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `Sources/ZipMaster/Resources/Engines/7zz`、`.../unrar`，均为 arm64 可执行；`build-engines.sh` 幂等（已存在则跳过）。

- [ ] **Step 1: 写 `scripts/build-engines.sh`**

`set -euo pipefail`；工作目录用 `mktemp -d`。
- 7-Zip：`git clone --depth 1 https://github.com/ip7z/7zip`；`cd CPP/7zip/Bundles/Alone2 && make -f makefile.gcc`（**需要时**追加 `PLATFORM` 探测）；产物 `b/g/7zz` 拷贝到 `Resources/Engines/7zz`。
- unrar：`curl -L https://www.rarlab.com/rar/unrarsrc-7.3.1.tar.gz | tar xz`；`cd unrar && make -f makefile CXXFLAGS="-O2 -D_FILE_OFFSET_BITS=64 -D_MACOSX"`；产物 `unrar` 拷贝到 `Resources/Engines/unrar`。
- 已存在则跳过（幂等）。

- [ ] **Step 2: 运行并验证架构**

Run: `chmod +x scripts/build-engines.sh && ./scripts/build-engines.sh`
Run: `lipo -info Sources/ZipMaster/Resources/Engines/7zz`
Expected: `Non-fat file ... architecture: arm64`
Run: `lipo -info Sources/ZipMaster/Resources/Engines/unrar`
Expected: `architecture: arm64`

- [ ] **Step 3: 验证引擎可运行**

Run: `Sources/ZipMaster/Resources/Engines/7zz i | head -5`
Expected: 打印 7-Zip 版本与格式列表（含 Rar、7z、zip）。
Run: `Sources/ZipMaster/Resources/Engines/unrar | head -3`
Expected: 打印 unrar 帮助/版本。

- [ ] **Step 4: 更新 `.gitignore` 与提交**

`.gitignore` 加入 `Sources/ZipMaster/Resources/Engines/7zz`、`.../unrar`，并保留 `.gitkeep`。

```bash
git add scripts/build-engines.sh Sources/ZipMaster/Resources/Engines/.gitkeep .gitignore
git commit -m "build: add arm64 engine build script for 7zz and unrar"
```

---

### Task 3: EngineLocator 与 ArchiveFormat

**Files:**
- Create: `Sources/ZipMaster/Core/ArchiveFormat.swift`
- Create: `Sources/ZipMaster/Core/EngineLocator.swift`
- Create: `Sources/ZipMaster/Core/ArchiveError.swift`
- Test: `Tests/ZipMasterTests/EngineLocatorTests.swift`
- Test: `Tests/ZipMasterTests/ArchiveFormatTests.swift`

**Interfaces:**
- Produces:
  - `enum ArchiveFormat: String, CaseIterable { case zip, sevenZip = "7z", tar, gzip = "gz", bzip2 = "bz2", xz }`，含 `var fileExtension: String`、`var sevenZipFlag: String`（`-tzip`/`-t7z`/`-ttar`/`-tgzip`/`-tbzip2`/`-txz`）。
  - `struct EngineLocator { init(searchPaths: [URL]); func locate(_ name: String) -> URL? }`；解析顺序：环境变量 `ZIPMASTER_ENGINES_DIR` → `Bundle.main.resourceURL/Engines` → 仓库开发路径。找不到返回 `nil`。
  - `enum ArchiveError: Error, Equatable { case engineNotFound(String); case processFailed(exitCode: Int32, message: String); case cancelled }`，且 `LocalizedError`（中文 `errorDescription`）。

- [ ] **Step 1: 写失败测试 `ArchiveFormatTests.swift`**

断言每种格式的 `fileExtension` 与 `sevenZipFlag` 精确值（如 `.sevenZip.fileExtension == "7z"`、`.sevenZip.sevenZipFlag == "-t7z"`）。

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter ArchiveFormatTests`
Expected: 编译失败/测试失败（类型不存在）。

- [ ] **Step 3: 实现 `ArchiveFormat.swift` 与 `ArchiveError.swift`**

- [ ] **Step 4: 写失败测试 `EngineLocatorTests.swift`**

用 `searchPaths` 指向临时目录放一个假 `7zz` 文件：`locate("7zz")` 返回该 URL；空目录时返回 `nil`；验证 `engineNotFound` 错误的中文描述。

- [ ] **Step 5: 实现 `EngineLocator.swift`，运行测试通过**

Run: `swift test --filter EngineLocatorTests`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add Sources/ZipMaster/Core Tests/ZipMasterTests
git commit -m "feat: add ArchiveFormat, EngineLocator and ArchiveError"
```

---

### Task 4: ProcessRunning 与 SevenZipEngine 压缩

**Files:**
- Create: `Sources/ZipMaster/Core/ProcessRunning.swift`
- Create: `Sources/ZipMaster/Core/SevenZipEngine.swift`
- Test: `Tests/ZipMasterTests/SevenZipEngineTests.swift`

**Interfaces:**
- Produces:
  - `protocol ProcessRunning: AnyObject { func run(executable: URL, arguments: [String], onOutput: @escaping (String) -> Void) async throws; func cancel() }`（`run` 在非零退出时抛 `ArchiveError.processFailed`）。
  - `final class ProcessRunner: ProcessRunning`（真实实现）。
  - `final class SevenZipEngine: ArchiveEngine { init(sevenZip: URL, runner: ProcessRunning) }`。
  - `ArchiveEngine` 协议：`func create(archive: URL, from sources: [URL], format: ArchiveFormat, onProgress: @escaping (Double) -> Void) async throws`。
  - 7zz 压缩参数：`["a", format.sevenZipFlag, "-bsp1", "-y", archive.path] + sources.map(\.path)`。

- [ ] **Step 1: 写失败测试（集成，需引擎）**

用 `XCTSkipIf` 在引擎缺失时跳过。临时目录建 `a.txt`（内容含空格与中文文件名 `含 空格.txt`）；调用 `create(archive: .../out.zip, from: [file], format: .zip, onProgress: {_ in})`；断言 `out.zip` 存在，且用 `7zz l out.zip`（通过 `ProcessRunner`）输出包含文件名。

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter SevenZipEngineTests`
Expected: FAIL（类型/方法不存在）。

- [ ] **Step 3: 实现 `ProcessRunning.swift`**

`ProcessRunner.run`：`Process`、`Pipe` 到 stdout/stderr；stdout 逐行回调 `onOutput`；`waitUntilExit`；`terminationStatus != 0` 抛 `processFailed`。`cancel()` 调 `process.terminate()`。

- [ ] **Step 4: 实现 `SevenZipEngine.create`**

组装参数（见 Interfaces），跑 `runner.run`，从 `onOutput` 里解析进度（委托 Task 7 的解析器；本任务先传 `nil` 亦可，测试不依赖进度值）。

- [ ] **Step 5: 运行集成测试通过**

Run: `swift test --filter SevenZipEngineTests`
Expected: PASS（引擎存在时）；打印 SKIP 除非引擎缺失。

- [ ] **Step 6: 提交**

```bash
git add Sources/ZipMaster/Core Tests/ZipMasterTests
git commit -m "feat: add ProcessRunning and 7zz-based compression"
```

---

### Task 5: SevenZipEngine 解压

**Files:**
- Modify: `Sources/ZipMaster/Core/SevenZipEngine.swift`
- Test: `Tests/ZipMasterTests/SevenZipEngineTests.swift`

**Interfaces:**
- Produces: `SevenZipEngine.extract(archive: URL, to destination: URL, onProgress:)`；参数 `["x", "-bsp1", "-y", "-aoa", "-o\(destination.path)", archive.path]`（`-aoa` 覆盖同名文件）。

- [ ] **Step 1: 写失败测试**

把 Task 4 生成的 `out.zip` 解到新目录，断言原文件（含中文文件名）被还原且内容一致；再解一次到同一目录，断言覆盖不报错。

- [ ] **Step 2: 运行确认失败** —— `swift test --filter SevenZipEngineTests` Expected: FAIL。

- [ ] **Step 3: 实现 `extract`**

- [ ] **Step 4: 运行测试通过** —— Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add Sources/ZipMaster/Core/SevenZipEngine.swift Tests/ZipMasterTests/SevenZipEngineTests.swift
git commit -m "feat: add 7zz-based extraction"
```

---

### Task 6: UnrarEngine（rar 解压）

**Files:**
- Create: `Sources/ZipMaster/Core/UnrarEngine.swift`
- Test: `Tests/ZipMasterTests/UnrarEngineTests.swift`
- Create: `Tests/ZipMasterTests/Fixtures/sample.rar`（人工准备的小 rar 样本）

**Interfaces:**
- Produces: `final class UnrarEngine: ArchiveEngine { init(unrar: URL, runner: ProcessRunning) }`；`create` 抛 `ArchiveError.processFailed`（不支持 RAR 压缩）或专用错误；`extract` 参数 `["x", "-o+", "-idq", archive.path, destination.path + "/"]`。

- [ ] **Step 1: 写单元测试（参数/不支持压缩）**

断言 `UnrarEngine.create` 抛错（RAR 压缩不支持）；若 `Fixtures/sample.rar` 存在，用 `ProcessRunner` 记录将被调用的参数 `x -o+ -idq`。

- [ ] **Step 2: 实现 `UnrarEngine`，运行单元测试通过**

Run: `swift test --filter UnrarEngineTests` Expected: PASS。

- [ ] **Step 3: 集成测试（fixture 存在时）**

解压 `sample.rar` 到临时目录，断言解出预期文件（`XCTSkip` 若 fixture 缺失）。

- [ ] **Step 4: 提交**

```bash
git add Sources/ZipMaster/Core/UnrarEngine.swift Tests/ZipMasterTests/UnrarEngineTests.swift Tests/ZipMasterTests/Fixtures/sample.rar
git commit -m "feat: add unrar-based extraction for rar archives"
```

---

### Task 7: 进度解析

**Files:**
- Create: `Sources/ZipMaster/Core/ProgressParser.swift`
- Test: `Tests/ZipMasterTests/ProgressParserTests.swift`

**Interfaces:**
- Produces: `enum ProgressParser { static func parseSevenZip(_ line: String) -> Double?; static func parseUnrar(_ line: String) -> Double? }`，返回 0.0–1.0。

- [ ] **Step 1: 写失败测试**

样例输入：7zz `" 45% 12 - file.txt"` → `0.45`；`"  0% 1 + a"` → `0.0`；`"100% 12 - file.txt"` → `1.0`；乱码/无百分比 `"Extracting foo"` → `nil`。unrar：`"Extracting  file               50%"` → `0.5`。

- [ ] **Step 2: 运行确认失败** —— Expected: FAIL。

- [ ] **Step 3: 实现 `ProgressParser`（正则容错，解析不到返回 `nil`）**

- [ ] **Step 4: 运行测试通过** —— Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add Sources/ZipMaster/Core/ProgressParser.swift Tests/ZipMasterTests/ProgressParserTests.swift
git commit -m "feat: add tolerant progress parsers for 7zz and unrar"
```

---

### Task 8: ArchiveJob（状态 / 进度 / 取消）

**Files:**
- Create: `Sources/ZipMaster/Core/ArchiveJob.swift`
- Test: `Tests/ZipMasterTests/ArchiveJobTests.swift`

**Interfaces:**
- Produces: `@MainActor final class ArchiveJob: ObservableObject { enum State: Equatable { case idle, running, succeeded, failed(String), cancelled }; @Published var state: State; @Published var progress: Double; init(engine: ArchiveEngine); func startExtract(archive: URL, to: URL); func startCreate(archive: URL, from: [URL], format: ArchiveFormat); func cancel() }`。

- [ ] **Step 1: 写失败测试（用假 engine）**

假 `ArchiveEngine` 可控制完成/抛错/被取消。断言：初始 `.idle`；`startExtract` 后 `.running`；成功→`.succeeded`；engine 抛 `processFailed`→`.failed`；`cancel()` 后→`.cancelled`。用 `XCTestExpectation` 等待 `@Published` 变化。

- [ ] **Step 2: 运行确认失败** —— Expected: FAIL。

- [ ] **Step 3: 实现 `ArchiveJob`**

`start*` 在 `Task` 中 await engine；`cancel()` 调用 engine 的 runner `cancel()` 并把非 `.cancelled` 错误映射为 `.cancelled`；进度回调切回主 actor 写 `progress`。

- [ ] **Step 4: 运行测试通过** —— Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add Sources/ZipMaster/Core/ArchiveJob.swift Tests/ZipMasterTests/ArchiveJobTests.swift
git commit -m "feat: add ArchiveJob state machine with progress and cancellation"
```

---

### Task 9: SwiftUI 界面（压缩 / 解压 / 拖拽 / 进度 / 错误）

**Files:**
- Modify: `Sources/ZipMaster/Views/MainView.swift`
- Create: `Sources/ZipMaster/Views/FormatPicker.swift`
- Create: `Sources/ZipMaster/Views/ProgressView.swift`
- Create: `Sources/ZipMaster/Core/AppModel.swift`

**Interfaces:**
- Consumes: `EngineLocator`、`SevenZipEngine`、`UnrarEngine`、`ArchiveJob`、`ArchiveFormat`。
- Produces: `@MainActor final class AppModel: ObservableObject`：持有 `job: ArchiveJob`、`func extract(archive:to:)`、`func create(archive:from:format:)`、`var errorMessage: String?`；启动时用 `EngineLocator` 解析 `7zz`/`unrar`，若缺失则 `errorMessage` 设为"请先运行 scripts/build-engines.sh"。

- [ ] **Step 1: 实现 `AppModel`（不写测试，靠 Task 8 已测的 job）**

- [ ] **Step 2: 实现 `MainView`（两个卡片：解压、压缩）**

解压：`.fileImporter` 选包 + 选输出目录 → 触发 `extract`。压缩：`.fileImporter`（多选）+ `FormatPicker` + 输出路径 → 触发 `create`。支持 `.onDrop` 拖入文件。按扩展名 `.rar` 时解压走 `UnrarEngine`，否则 `SevenZipEngine`。

- [ ] **Step 3: 实现 `ProgressView`（进度条 + 取消按钮）与错误 `.alert`**

- [ ] **Step 4: 重新打包并手动冒烟**

Run: `./scripts/build-app.sh && open ZipMaster.app`
Expected: 用界面压缩一个含中文名的文件夹为 `zip`，再解压到新目录，内容一致；进度条推进；取消可中断。

- [ ] **Step 5: 提交**

```bash
git add Sources/ZipMaster/Views Sources/ZipMaster/Core/AppModel.swift
git commit -m "feat: add SwiftUI compress/decompress UI with drag-and-drop"
```

---

### Task 10: 文档与许可证

**Files:**
- Create: `README.md`
- Create: `LICENSES.md`

- [ ] **Step 1: 写 `README.md`**

说明：项目目的（替代 Intel-only 360压缩大师）、支持格式表、构建步骤（`./scripts/build-engines.sh` → `./scripts/build-app.sh` → `open ZipMaster.app`）、已知限制（不做 RAR 压缩等）、Gatekeeper 处理提示。

- [ ] **Step 2: 写 `LICENSES.md`**

列入 7-Zip（LGPL-2.1 + BSD-3 + unRAR restriction）与 unrar（freeware，仅解压用途）的授权说明与出处 URL。

- [ ] **Step 3: 全量测试回归**

Run: `swift test`
Expected: 全部 PASS 或按引擎/fixture 存在性 SKIP，无 FAIL。

- [ ] **Step 4: 提交**

```bash
git add README.md LICENSES.md
git commit -m "docs: add README and third-party licenses"
```

---

## Self-Review

- **Spec coverage:** 目标 1（arm64）→ Task 2；目标 2（基础压缩/解压）→ Task 4/5/6/9；目标 3（格式对齐）→ Task 2/3/6；目标 4（自建）→ Task 1/2/9；目标 5（引擎开源可复现）→ Task 2/10。非目标均在 Global Constraints 明确排除。§6 错误处理 → Task 3/8；§7 测试 → 各 Task 测试步骤。
- **Type consistency:** `ArchiveEngine`、`ArchiveFormat`、`ProcessRunning`、`EngineLocator`、`ArchiveJob.State` 在 Task 3/4/6/8 的定义与后续引用一致。
- **Review Focus:** 每条已在对应 Task 的测试步骤落地（见 Review Focus 内标注）。
- **Proportion:** 计划以签名、参数与测试断言为主，未转写实现体。
