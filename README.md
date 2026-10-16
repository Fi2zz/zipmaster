# ZipMaster

原生 **Apple Silicon（arm64）** 的 macOS 压缩/解压应用，作为仅支持 Intel 的「360压缩大师」的替代。
界面用 SwiftUI 从零重写；压缩/解压核心换成开源引擎 **7-Zip（`7zz`）** 与 **unrar**，在目标机器上原生编译为 arm64。

## 特性

- **压缩**：`zip` / `7z` / `tar` / `gz` / `bz2` / `xz`
- **解压**：以上格式，外加 `rar`/`rar5`、`cab`、`iso`、`cpio`、`lzh`、`ar`、`rpm` 等（由 7-Zip 读取）
- 原生 arm64，不依赖 Rosetta
- 拖拽、进度显示、可取消

## 环境要求

- Apple Silicon Mac（M 系列）
- macOS 13 或更高
- Xcode / Swift 工具链（`swift` 可用）

## 构建

```bash
./scripts/build-engines.sh   # 拉取源码并原生编译 arm64 引擎（首次约几分钟）
./scripts/build-app.sh       # 组装 ZipMaster.app 并做 ad-hoc 签名
open ZipMaster.app
```

## 支持格式

| 格式 | 压缩 | 解压 |
|---|---|---|
| zip / 7z / tar / gz / bz2 / xz | ✅ | ✅ |
| rar / rar5 | ❌（算法专有） | ✅ |
| cab / iso / cpio / lzh / ar / rpm | ❌ | ✅ |

## 已知限制（第一版）

- 不支持 **创建** RAR 压缩包（RAR 压缩算法为专有，无法合法实现）。
- 暂不做：密码/加密包、分卷/多卷、Finder 右键菜单、包内文件列表与选择性解压。
- 未做应用分发与公证，仅本机 ad-hoc 签名，供自用/开发。

## Gatekeeper

本机构建的产物一般可直接运行；若被拦截，可解除隔离属性：

```bash
xattr -dr com.apple.quarantine ZipMaster.app
```

## 授权

本项目自身代码以 **MIT** 发布；随包分发的第三方引擎（7-Zip、unrar）授权见 [LICENSES.md](LICENSES.md)。
