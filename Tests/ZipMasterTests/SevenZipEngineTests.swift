import XCTest
@testable import ZipMaster

final class SevenZipEngineTests: XCTestCase {
    private func engineURL() throws -> URL {
        guard let url = TestEngines.locate("7zz") else {
            throw XCTSkip("7zz 未构建，跳过（运行 scripts/build-engines.sh）")
        }
        return url
    }

    func testCreateZipWithSpacesAndUnicode() async throws {
        let sevenZip = try engineURL()
        let engine = SevenZipEngine(sevenZip: sevenZip)
        let tmp = try makeTempDir()
        let input = tmp.appendingPathComponent("含 空格.txt")
        try Data("hello 世界".utf8).write(to: input)
        let archive = tmp.appendingPathComponent("out.zip")

        try await engine.create(archive: archive, from: [input], format: .zip, onProgress: { _ in })

        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
        let listing = try await list(sevenZip, archive)
        XCTAssertTrue(listing.contains("含 空格.txt"), "listing was: \(listing)")
    }

    func testCreateReportsProgress() async throws {
        let sevenZip = try engineURL()
        let engine = SevenZipEngine(sevenZip: sevenZip)
        let tmp = try makeTempDir()
        var sources: [URL] = []
        // 不可压缩数据、足够大，确保 7zz 至少上报一次中间进度。
        for index in 1...3 {
            let file = tmp.appendingPathComponent("f\(index).bin")
            try randomData(3 * 1024 * 1024).write(to: file)
            sources.append(file)
        }
        let archive = tmp.appendingPathComponent("out.7z")

        var progresses: [Double] = []
        try await engine.create(archive: archive, from: sources, format: .sevenZip, onProgress: { progresses.append($0) })

        XCTAssertGreaterThan(progresses.max() ?? 0, 0, "进度应推进，实际: \(progresses)")
    }

    private func randomData(_ bytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/urandom"))
        defer { try? handle.close() }
        return handle.readData(ofLength: bytes)
    }

    func testExtractRestoresUnicodeFileName() async throws {
        let sevenZip = try engineURL()
        let engine = SevenZipEngine(sevenZip: sevenZip)
        let tmp = try makeTempDir()
        let input = tmp.appendingPathComponent("含 空格.txt")
        try Data("hello 世界".utf8).write(to: input)
        let archive = tmp.appendingPathComponent("out.zip")
        try await engine.create(archive: archive, from: [input], format: .zip, onProgress: { _ in })

        let out = tmp.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try await engine.extract(archive: archive, to: out, onProgress: { _ in })

        let restored = out.appendingPathComponent("含 空格.txt")
        XCTAssertEqual(try String(contentsOf: restored, encoding: .utf8), "hello 世界")
    }

    func testExtractOverwritesExistingWithoutError() async throws {
        let sevenZip = try engineURL()
        let engine = SevenZipEngine(sevenZip: sevenZip)
        let tmp = try makeTempDir()
        let input = tmp.appendingPathComponent("a.txt")
        try Data("v1".utf8).write(to: input)
        let archive = tmp.appendingPathComponent("out.zip")
        try await engine.create(archive: archive, from: [input], format: .zip, onProgress: { _ in })

        let out = tmp.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try await engine.extract(archive: archive, to: out, onProgress: { _ in })
        // 第二次解压到同一目录应覆盖、不抛错
        try await engine.extract(archive: archive, to: out, onProgress: { _ in })

        XCTAssertEqual(try String(contentsOf: out.appendingPathComponent("a.txt"), encoding: .utf8), "v1")
    }

    func testCreateReplacesExistingArchive() async throws {
        let sevenZip = try engineURL()
        let engine = SevenZipEngine(sevenZip: sevenZip)
        let tmp = try makeTempDir()
        let a = tmp.appendingPathComponent("a.txt")
        try Data("a".utf8).write(to: a)
        let b = tmp.appendingPathComponent("b.txt")
        try Data("b".utf8).write(to: b)
        let archive = tmp.appendingPathComponent("out.zip")

        try await engine.create(archive: archive, from: [a], format: .zip, onProgress: { _ in })
        try await engine.create(archive: archive, from: [b], format: .zip, onProgress: { _ in })

        let listing = try await list(sevenZip, archive)
        XCTAssertTrue(listing.contains("b.txt"), "listing: \(listing)")
        XCTAssertFalse(listing.contains("a.txt"), "陈旧条目未清除: \(listing)")
    }

    // MARK: - helpers

    private func list(_ sevenZip: URL, _ archive: URL) async throws -> String {
        var out = ""
        try await ProcessRunner().run(executable: sevenZip, arguments: ["l", "-ba", archive.path]) { line in
            out += line + "\n"
        }
        return out
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }
}
