import Foundation
import Combine

/// 驱动一次压缩/解压，并对外暴露状态、进度与取消能力。
@MainActor
final class ArchiveJob: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case succeeded
        case cancelled
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var progress: Double = 0

    private let engine: ArchiveEngine
    private var task: Task<Void, Never>?
    private var cancelled = false

    init(engine: ArchiveEngine) {
        self.engine = engine
    }

    func startExtract(archive: URL, to destination: URL) {
        run { [engine] onProgress in
            try await engine.extract(archive: archive, to: destination, onProgress: onProgress)
        }
    }

    func startCreate(archive: URL, from sources: [URL], format: ArchiveFormat) {
        run { [engine] onProgress in
            try await engine.create(archive: archive, from: sources, format: format, onProgress: onProgress)
        }
    }

    func cancel() {
        cancelled = true
        task?.cancel()
        engine.cancel()
        state = .cancelled
    }

    // MARK: - private

    private func run(_ operation: @escaping (@escaping (Double) -> Void) async throws -> Void) {
        cancelled = false
        state = .running
        progress = 0

        let onProgress: (Double) -> Void = { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }

        task = Task { [weak self] in
            do {
                try await operation(onProgress)
                self?.finish(.succeeded)
            } catch {
                if let archiveError = error as? ArchiveError, case .cancelled = archiveError {
                    self?.finish(.cancelled)
                } else {
                    self?.finish(.failed(error.localizedDescription))
                }
            }
        }
    }

    private func finish(_ result: State) {
        // 用户已取消时，保持 cancelled，不被迟到的完成/错误覆盖。
        if cancelled {
            state = .cancelled
        } else {
            state = result
        }
    }
}
