import Foundation

/// 测试用：定位仓库内的引擎二进制（不依赖 app bundle）。
enum TestEngines {
    static var dir: URL {
        if let env = ProcessInfo.processInfo.environment["ZIPMASTER_ENGINES_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()   // Tests/ZipMasterTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
        return packageRoot.appendingPathComponent("Sources/ZipMaster/Resources/Engines", isDirectory: true)
    }

    static func locate(_ name: String) -> URL? {
        let candidate = dir.appendingPathComponent(name)
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    /// 测试 fixtures 目录（Tests/ZipMasterTests/Fixtures）。
    static var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }
}
