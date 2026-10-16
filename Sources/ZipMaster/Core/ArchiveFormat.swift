import Foundation

/// 本 App 第一版支持创建的压缩格式（读取由 7-Zip 覆盖更多格式）。
enum ArchiveFormat: String, CaseIterable {
    case zip
    case sevenZip = "7z"
    case tar
    case gzip = "gz"
    case bzip2 = "bz2"
    case xz

    /// 输出文件扩展名，与 rawValue 一致。
    var fileExtension: String { rawValue }

    /// 传给 7zz 的 `-t` 格式开关。
    var sevenZipFlag: String {
        switch self {
        case .zip: return "-tzip"
        case .sevenZip: return "-t7z"
        case .tar: return "-ttar"
        case .gzip: return "-tgzip"
        case .bzip2: return "-tbzip2"
        case .xz: return "-txz"
        }
    }
}
