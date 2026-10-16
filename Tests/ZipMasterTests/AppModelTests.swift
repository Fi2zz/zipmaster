import XCTest
@testable import ZipMaster

@MainActor
final class AppModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in ["7zz", "unrar"] {
            let url = dir.appendingPathComponent(name)
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testSingleFileFormatRejectsMultipleSources() throws {
        let model = AppModel(locator: EngineLocator(searchPaths: [dir]))
        let a = try makeFile("a.txt")
        let b = try makeFile("b.txt")

        model.create(archive: dir.appendingPathComponent("out.gz"), from: [a, b], format: .gzip)

        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.job)
    }

    func testSingleFileFormatRejectsDirectory() throws {
        let model = AppModel(locator: EngineLocator(searchPaths: [dir]))
        let folder = dir.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        model.create(archive: dir.appendingPathComponent("out.xz"), from: [folder], format: .xz)

        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.job)
    }

    func testZipAcceptsMultipleSources() throws {
        let model = AppModel(locator: EngineLocator(searchPaths: [dir]))
        let a = try makeFile("a.txt")
        let b = try makeFile("b.txt")

        model.create(archive: dir.appendingPathComponent("out.zip"), from: [a, b], format: .zip)

        XCTAssertNil(model.errorMessage)
        XCTAssertNotNil(model.job)
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }
}
