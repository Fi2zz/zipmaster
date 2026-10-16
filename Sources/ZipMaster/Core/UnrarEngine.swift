import Foundation

/// 基于 `unrar` 的引擎：仅用于解压 RAR。
/// RAR 压缩算法为专有，无法合法实现，故 `create` 一律抛错。
final class UnrarEngine: ArchiveEngine {
    private let unrar: URL
    private let runner: ProcessRunning

    init(unrar: URL, runner: ProcessRunning = ProcessRunner()) {
        self.unrar = unrar
        self.runner = runner
    }

    func create(archive: URL, from sources: [URL], format: ArchiveFormat,
                onProgress: @escaping (Double) -> Void) async throws {
        throw ArchiveError.unsupported("RAR 压缩算法为专有，无法创建 RAR 压缩包")
    }

    func extract(archive: URL, to destination: URL,
                 onProgress: @escaping (Double) -> Void) async throws {
        // 末尾斜杠表示解压到该目录；-o+ 覆盖同名文件。
        let args = ["x", "-o+", archive.path, destination.path + "/"]
        try await runner.run(executable: unrar, arguments: args) { line in
            if let value = ProgressParser.parseUnrar(line) { onProgress(value) }
        }
    }

    func cancel() {
        runner.cancel()
    }
}
