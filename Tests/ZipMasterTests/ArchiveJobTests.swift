import XCTest
@testable import ZipMaster

final class FakeEngine: ArchiveEngine {
    var extractBehavior: (URL, URL, @escaping (Double) -> Void) async throws -> Void = { _, _, _ in }
    private(set) var cancelCount = 0

    func create(archive: URL, from sources: [URL], format: ArchiveFormat,
                onProgress: @escaping (Double) -> Void) async throws {}

    func extract(archive: URL, to destination: URL,
                 onProgress: @escaping (Double) -> Void) async throws {
        try await extractBehavior(archive, destination, onProgress)
    }

    func cancel() { cancelCount += 1 }
}

@MainActor
final class ArchiveJobTests: XCTestCase {
    func testInitialStateIsIdle() {
        let job = ArchiveJob(engine: FakeEngine())
        XCTAssertEqual(job.state, .idle)
    }

    func testStartExtractRunningThenSucceededWithProgress() async throws {
        let engine = FakeEngine()
        engine.extractBehavior = { _, _, onProgress in onProgress(0.5) }
        let job = ArchiveJob(engine: engine)

        job.startExtract(archive: URL(fileURLWithPath: "/tmp/a.zip"), to: URL(fileURLWithPath: "/tmp/out"))
        XCTAssertEqual(job.state, .running)

        try await waitUntil { job.state == .succeeded && job.progress == 0.5 }
    }

    func testEngineFailureSetsFailed() async throws {
        let engine = FakeEngine()
        engine.extractBehavior = { _, _, _ in
            throw ArchiveError.processFailed(exitCode: 1, message: "boom")
        }
        let job = ArchiveJob(engine: engine)

        job.startExtract(archive: URL(fileURLWithPath: "/tmp/a.zip"), to: URL(fileURLWithPath: "/tmp/out"))
        try await waitUntil {
            if case .failed = job.state { return true }
            return false
        }
        if case .failed(let message) = job.state {
            XCTAssertTrue(message.contains("boom"), "message was: \(message)")
        } else {
            XCTFail("expected .failed, got \(job.state)")
        }
    }

    func testCancelSetsCancelledAndCallsEngine() async throws {
        let engine = FakeEngine()
        engine.extractBehavior = { _, _, _ in
            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        let job = ArchiveJob(engine: engine)

        job.startExtract(archive: URL(fileURLWithPath: "/tmp/a.zip"), to: URL(fileURLWithPath: "/tmp/out"))
        XCTAssertEqual(job.state, .running)

        job.cancel()
        XCTAssertEqual(job.state, .cancelled)
        XCTAssertEqual(engine.cancelCount, 1)
    }

    private func waitUntil(timeout: TimeInterval = 3, condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("timeout waiting for condition")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
