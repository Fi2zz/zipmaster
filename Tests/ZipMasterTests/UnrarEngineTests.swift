import XCTest
@testable import ZipMaster

/// 记录被调用参数的假 runner，用于固定引擎的实参构造。
final class MockRunner: ProcessRunning {
    private(set) var calls: [(executable: URL, arguments: [String])] = []
    var cancelled = false

    func run(executable: URL, arguments: [String], onOutput: @escaping (String) -> Void) async throws {
        calls.append((executable, arguments))
    }

    func cancel() { cancelled = true }
}

final class UnrarEngineTests: XCTestCase {
    func testExtractPassesExpectedArguments() async throws {
        let runner = MockRunner()
        let unrar = URL(fileURLWithPath: "/tmp/unrar")
        let engine = UnrarEngine(unrar: unrar, runner: runner)
        let archive = URL(fileURLWithPath: "/tmp/x.rar")
        let dest = URL(fileURLWithPath: "/tmp/out")

        try await engine.extract(archive: archive, to: dest, onProgress: { _ in })

        XCTAssertEqual(runner.calls.count, 1)
        XCTAssertEqual(runner.calls[0].executable, unrar)
        XCTAssertEqual(runner.calls[0].arguments, ["x", "-o+", "/tmp/x.rar", "/tmp/out/"])
    }

    func testCreateRARThrowsUnsupported() async {
        let engine = UnrarEngine(unrar: URL(fileURLWithPath: "/tmp/unrar"), runner: MockRunner())
        do {
            try await engine.create(archive: URL(fileURLWithPath: "/tmp/x.rar"),
                                    from: [], format: .zip, onProgress: { _ in })
            XCTFail("创建 RAR 应抛错")
        } catch {
            // 预期：RAR 压缩算法专有，不支持创建
        }
    }

    func testExtractRealRARFixture() async throws {
        guard let unrar = TestEngines.locate("unrar") else {
            throw XCTSkip("unrar 未构建，跳过（运行 scripts/build-engines.sh）")
        }
        let fixture = TestEngines.fixturesDir.appendingPathComponent("sample.rar")
        guard FileManager.default.fileExists(atPath: fixture.path) else {
            throw XCTSkip("缺少 Fixtures/sample.rar")
        }
        let engine = UnrarEngine(unrar: unrar)
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: out) }

        try await engine.extract(archive: fixture, to: out, onProgress: { _ in })

        let restored = out.appendingPathComponent("数据 文件.txt")
        XCTAssertEqual(try String(contentsOf: restored, encoding: .utf8), "hello 世界\n")
    }
}
