import XCTest
@testable import ZipMaster

final class EngineLocatorTests: XCTestCase {
    func testLocatesExecutableInSearchPath() throws {
        let dir = try makeTempDir()
        let fake = dir.appendingPathComponent("7zz")
        try Data("#!/bin/sh\n".utf8).write(to: fake)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)

        let locator = EngineLocator(searchPaths: [dir])
        XCTAssertEqual(locator.locate("7zz"), fake)
    }

    func testReturnsNilWhenMissing() throws {
        let dir = try makeTempDir()
        let locator = EngineLocator(searchPaths: [dir])
        XCTAssertNil(locator.locate("7zz"))
    }

    func testIgnoresNonExecutableFile() throws {
        let dir = try makeTempDir()
        let fake = dir.appendingPathComponent("7zz")
        try Data("not executable".utf8).write(to: fake)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fake.path)

        let locator = EngineLocator(searchPaths: [dir])
        XCTAssertNil(locator.locate("7zz"))
    }

    func testEngineNotFoundErrorDescription() {
        let err = ArchiveError.engineNotFound("7zz")
        XCTAssertEqual(err.errorDescription, "找不到引擎 7zz，请先运行 scripts/build-engines.sh")
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }
}
