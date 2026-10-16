import Foundation

/// 子进程执行抽象，便于在测试中替换。
protocol ProcessRunning: AnyObject {
    func run(executable: URL, arguments: [String], onOutput: @escaping (String) -> Void) async throws
    func cancel()
}

/// 真实实现：用 `Process` 跑引擎，逐行回调输出，非零退出抛 `ArchiveError.processFailed`。
///
/// 取消语义：`cancel()` 可先于 `run()` 调用（含任务已调度但尚未启动的窗口）；
/// 此时 `run` 会立即抛 `ArchiveError.cancelled`，或启动后立刻终止子进程。
final class ProcessRunner: ProcessRunning {
    private var process: Process?
    private var cancelledFlag = false
    private let lock = NSLock()

    func run(executable: URL, arguments: [String], onOutput: @escaping (String) -> Void) async throws {
        if isCancelled { throw ArchiveError.cancelled }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let liner = LineBuffer(onLine: onOutput)
        let errCollector = DataCollector()
        // 并发排空 stdout 与 stderr，避免子进程因管道写满而阻塞。
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { liner.append(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { errCollector.append(data) }
        }

        setProcess(process)
        defer { clearProcess() }

        let status: Int32 = try await withCheckedThrowingContinuation { cont in
            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                let outRest = stdout.fileHandleForReading.readDataToEndOfFile()
                if !outRest.isEmpty { liner.append(outRest) }
                liner.flush()
                let errRest = stderr.fileHandleForReading.readDataToEndOfFile()
                if !errRest.isEmpty { errCollector.append(errRest) }
                cont.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
                // 覆盖“run 尚未启动时已被取消”的窗口。
                if self.isCancelled { process.terminate() }
            } catch {
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                cont.resume(throwing: error)
            }
        }

        if isCancelled { throw ArchiveError.cancelled }

        if status != 0 {
            let errText = String(decoding: errCollector.data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ArchiveError.processFailed(exitCode: status, message: errText)
        }
    }

    /// 请求取消；只对**已启动**的进程发送终止信号，避免对未启动任务调用 `terminate()` 崩溃。
    func cancel() {
        lock.lock()
        cancelledFlag = true
        let running = process
        lock.unlock()
        if let running, running.isRunning { running.terminate() }
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }

    // 在非 async 作用域内操作锁，避免在异步上下文中直接调用 NSLock。
    private func setProcess(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    private func clearProcess() {
        lock.lock()
        process = nil
        lock.unlock()
    }
}

/// 线程安全地累积字节（用于排空 stderr）。
final class DataCollector {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// 把流入的字节切成行：以 `\n`、`\r` 及 7-Zip 原位刷新用的退格 `\b` 为分隔。
/// 以字节缓冲，保证跨读取被切断的多字节 UTF-8 字符不丢失。
final class LineBuffer {
    private let lock = NSLock()
    private var buffer = Data()
    private let onLine: (String) -> Void
    private static let delimiters: Set<UInt8> = [0x0A, 0x0D, 0x08]

    init(onLine: @escaping (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        var lines: [String] = []
        lock.lock()
        buffer.append(data)
        while let idx = buffer.firstIndex(where: { Self.delimiters.contains($0) }) {
            let segment = buffer[buffer.startIndex..<idx]
            if !segment.isEmpty { lines.append(String(decoding: segment, as: UTF8.self)) }
            buffer.removeSubrange(buffer.startIndex...idx)
        }
        lock.unlock()
        for line in lines where !line.isEmpty { onLine(line) }
    }

    func flush() {
        lock.lock()
        let remaining = buffer
        buffer.removeAll(keepingCapacity: false)
        lock.unlock()
        if !remaining.isEmpty { onLine(String(decoding: remaining, as: UTF8.self)) }
    }
}
