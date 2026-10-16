import Foundation

/// 从引擎的输出行中提取百分比进度，返回 0.0–1.0。
/// 解析不到时返回 nil（调用方退化为不确定进度，不应报错）。
enum ProgressParser {
    static func parseSevenZip(_ line: String) -> Double? { percent(in: line) }
    static func parseUnrar(_ line: String) -> Double? { percent(in: line) }

    /// 匹配第一个形如 `45%` 的百分比；合法范围 0–100，越界视为无效。
    private static func percent(in line: String) -> Double? {
        guard let range = line.range(of: #"\d{1,3}\s*%"#, options: .regularExpression) else {
            return nil
        }
        let digits = line[range].prefix { $0.isNumber }
        guard let value = Int(digits), (0...100).contains(value) else {
            return nil
        }
        return Double(value) / 100.0
    }
}
