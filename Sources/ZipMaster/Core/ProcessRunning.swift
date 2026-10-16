import Foundation

/// 子进程执行抽象，便于在测试中替换。
protocol ProcessRunning: AnyObject {
    func run(executable: URL, arguments: [String], onOutput: @escaping (String) -> Void) async throws
    func cancel()
}

/// 真实实现：用 `Process` 跑引擎，逐行回调输出，非零退出抛 `ArchiveError.processFailed`。
final class ProcessRunner: ProcessRunning {
    private var process: Process?
    private let lock = NSLock()

    func run(executable: URL, arguments: [String], onOutput: @escaping (String) -> Void) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let liner = LineBuffer(onLine: onOutput)
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { liner.append(data) }
        }

        lock.lock(); self.process = process; lock.unlock()

        let status: Int32 = try await withCheckedThrowingContinuation { cont in
            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                let rest = stdout.fileHandleForReading.readDataToEndOfFile()
                if !rest.isEmpty { liner.append(rest) }
                liner.flush()
                cont.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }

        lock.lock(); self.process = nil; lock.unlock()

        if status != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errText = (String(data: errData, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ArchiveError.processFailed(exitCode: status, message: errText)
        }
    }

    func cancel() {
        lock.lock()
        let p = process
        lock.unlock()
        p?.terminate()
    }
}

/// 把流入的字节按 CR/LF 切分成行（7-Zip 用 `\r` 刷新进度）。
final class LineBuffer {
    private let lock = NSLock()
    private var pending = ""
    private let onLine: (String) -> Void

    init(onLine: @escaping (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        pending += text
        var lines: [String] = []
        while let idx = pending.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            lines.append(String(pending[pending.startIndex..<idx]))
            pending.removeSubrange(pending.startIndex...idx)
        }
        lock.unlock()
        for line in lines where !line.isEmpty { onLine(line) }
    }

    func flush() {
        lock.lock()
        let line = pending
        pending = ""
        lock.unlock()
        if !line.isEmpty { onLine(line) }
    }
}
