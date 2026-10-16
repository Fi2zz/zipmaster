import Foundation

/// 定位随包分发的引擎二进制（7zz / unrar）。
struct EngineLocator {
    let searchPaths: [URL]

    /// 显式指定搜索路径（测试用）。
    init(searchPaths: [URL]) {
        self.searchPaths = searchPaths
    }

    /// 生产用法：环境变量 `ZIPMASTER_ENGINES_DIR` > App bundle 的 Resources/Engines。
    init() {
        var paths: [URL] = []
        if let env = ProcessInfo.processInfo.environment["ZIPMASTER_ENGINES_DIR"], !env.isEmpty {
            paths.append(URL(fileURLWithPath: env, isDirectory: true))
        }
        if let res = Bundle.main.resourceURL {
            paths.append(res.appendingPathComponent("Engines", isDirectory: true))
        }
        self.searchPaths = paths
    }

    /// 在搜索路径中查找可执行文件；找不到返回 nil。
    func locate(_ name: String) -> URL? {
        for dir in searchPaths {
            let candidate = dir.appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
