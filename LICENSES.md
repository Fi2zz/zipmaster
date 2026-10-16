# 第三方引擎授权

ZipMaster 随包分发两个开源/免费引擎，均由 `scripts/build-engines.sh` 在目标机器上从源码原生编译为 arm64。

## 7-Zip（`7zz`）

- 出处：https://github.com/ip7z/7zip
- 授权：主体为 **GNU LGPL-2.1**，部分组件为 **BSD-3-Clause**，并附带 **unRAR 限制条款**
  （即其 RAR 解压代码不得用于重新实现 RAR 压缩算法）。
- 用途：zip/7z/tar/gz/bz2/xz 的压缩与解压，及 rar/cab/iso/cpio/lzh/ar/rpm 等的解压。

## unrar

- 出处：https://www.rarlab.com/rar/unrarsrc-7.3.1.tar.gz
- 授权：**freeware** 许可。允许用于解压 RAR 压缩包；
  禁止使用其代码/二进制重新实现 RAR 压缩算法。
- 用途：RAR / RAR5 解压。

## 说明

上述授权允许在本项目中随应用一起分发对应二进制，但使用者需遵守各自条款。
若你重新分发本应用，请一并保留本文件及各引擎的授权文本。
