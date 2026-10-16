import Foundation
import Combine

/// 界面状态：持有当前任务、解析引擎、并在缺少引擎时给出提示。
@MainActor
final class AppModel: ObservableObject {
    @Published var errorMessage: String?
    @Published private(set) var job: ArchiveJob?

    private let sevenZip: URL?
    private let unrar: URL?

    init(locator: EngineLocator = EngineLocator()) {
        self.sevenZip = locator.locate("7zz")
        self.unrar = locator.locate("unrar")
        if sevenZip == nil || unrar == nil {
            self.errorMessage = "找不到压缩引擎，请先运行 scripts/build-engines.sh 后重新打包"
        }
    }

    /// 解压：`.rar` 走 unrar，其它格式走 7zz。
    func extract(archive: URL, to destination: URL) {
        let engine: ArchiveEngine?
        if archive.pathExtension.lowercased() == "rar" {
            engine = unrar.map { UnrarEngine(unrar: $0) }
        } else {
            engine = sevenZip.map { SevenZipEngine(sevenZip: $0) }
        }
        guard let engine else { reportMissingEngine(); return }
        job?.cancel()
        let job = ArchiveJob(engine: engine)
        self.job = job
        job.startExtract(archive: archive, to: destination)
    }

    /// 压缩：始终使用 7zz（unrar 不能创建压缩包）。
    func create(archive: URL, from sources: [URL], format: ArchiveFormat) {
        guard let sevenZip else { reportMissingEngine(); return }
        guard Self.isValidSources(sources, for: format) else {
            errorMessage = "\(format.fileExtension) 只能压缩单个文件（不能是文件夹或多个文件）"
            return
        }
        job?.cancel()
        let job = ArchiveJob(engine: SevenZipEngine(sevenZip: sevenZip))
        self.job = job
        job.startCreate(archive: archive, from: sources, format: format)
    }

    func cancel() {
        job?.cancel()
    }

    /// gz/bz2/xz 是单文件格式：仅接受“恰好一个普通文件”。
    private static func isValidSources(_ sources: [URL], for format: ArchiveFormat) -> Bool {
        let singleFileFormats: Set<ArchiveFormat> = [.gzip, .bzip2, .xz]
        guard singleFileFormats.contains(format) else { return true }
        guard sources.count == 1, let first = sources.first else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: first.path, isDirectory: &isDirectory) else { return false }
        return !isDirectory.boolValue
    }

    private func reportMissingEngine() {
        errorMessage = "找不到引擎，请先运行 scripts/build-engines.sh 后重新打包"
    }
}
