import Foundation

enum ArchiveError: Error, Equatable {
    case engineNotFound(String)
    case processFailed(exitCode: Int32, message: String)
    case cancelled
}

extension ArchiveError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .engineNotFound(let name):
            return "找不到引擎 \(name)，请先运行 scripts/build-engines.sh"
        case .processFailed(let code, let message):
            return "引擎执行失败（退出码 \(code)）：\(message)"
        case .cancelled:
            return "操作已取消"
        }
    }
}
