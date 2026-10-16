import Foundation

/// 压缩/解压引擎的统一接口。
protocol ArchiveEngine: AnyObject {
    /// 把 `sources`（文件或文件夹）打包成 `archive`。
    func create(archive: URL, from sources: [URL], format: ArchiveFormat,
                onProgress: @escaping (Double) -> Void) async throws

    /// 终止正在进行的操作。
    func cancel()
}
