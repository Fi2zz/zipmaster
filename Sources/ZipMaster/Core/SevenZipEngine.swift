import Foundation

/// 基于 `7zz` 的引擎：覆盖 zip/7z/tar/gz/bz2/xz 的创建，及更多格式的读取。
final class SevenZipEngine: ArchiveEngine {
    private let sevenZip: URL
    private let runner: ProcessRunning

    init(sevenZip: URL, runner: ProcessRunning = ProcessRunner()) {
        self.sevenZip = sevenZip
        self.runner = runner
    }

    func create(archive: URL, from sources: [URL], format: ArchiveFormat,
                onProgress: @escaping (Double) -> Void) async throws {
        var args = ["a", format.sevenZipFlag, "-bsp1", "-y", archive.path]
        args += sources.map(\.path)
        try await runner.run(executable: sevenZip, arguments: args) { line in
            if let value = ProgressParser.parseSevenZip(line) { onProgress(value) }
        }
    }

    func extract(archive: URL, to destination: URL,
                 onProgress: @escaping (Double) -> Void) async throws {
        let args = ["x", "-bsp1", "-y", "-aoa", "-o\(destination.path)", archive.path]
        try await runner.run(executable: sevenZip, arguments: args) { line in
            if let value = ProgressParser.parseSevenZip(line) { onProgress(value) }
        }
    }

    func cancel() {
        runner.cancel()
    }
}
