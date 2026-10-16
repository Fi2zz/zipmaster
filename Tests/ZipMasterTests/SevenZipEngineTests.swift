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
        let input = tmp.appendingPathComponent("a.txt")
        try Data(String(repeating: "x", count: 100_000).utf8).write(to: input)
        let archive = tmp.appendingPathComponent("out.7z")

        var progresses: [Double] = []
        try await engine.create(archive: archive, from: [input], format: .sevenZip, onProgress: { progresses.append($0) })

        XCTAssertFalse(progresses.isEmpty, "应至少回调一次进度")
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
