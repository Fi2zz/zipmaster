import XCTest
@testable import ZipMaster

final class ProcessRunnerTests: XCTestCase {
    func testCancelTerminatesRunningProcess() async throws {
        let runner = ProcessRunner()
        let started = Date()
        let task = Task {
            try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"),
                                 arguments: ["30"], onOutput: { _ in })
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        runner.cancel()

        do {
            try await task.value
            XCTFail("取消后应抛错")
        } catch {
            // 预期：进程被终止导致非零退出
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testCancelBeforeLaunchDoesNotRun() async throws {
        let runner = ProcessRunner()
        runner.cancel()   // 启动前就请求取消

        do {
            try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"),
                                 arguments: ["3"], onOutput: { _ in })
            XCTFail("启动前已取消，不应真正执行")
        } catch ArchiveError.cancelled {
            // 预期
        }
    }

    func testLargeStderrDoesNotHang() async throws {
        // 子进程向 stderr 写入远超管道缓冲区的数据；若不并发排空会阻塞导致挂起。
        let runner = ProcessRunner()
        let script = "i=0; while [ $i -lt 30000 ]; do echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1>&2; i=$((i+1)); done"
        try await runner.run(executable: URL(fileURLWithPath: "/bin/sh"),
                             arguments: ["-c", script], onOutput: { _ in })
    }
}
