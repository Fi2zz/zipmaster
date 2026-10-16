import Foundation

/// 从引擎的输出行中提取百分比进度，返回 0.0–1.0。
/// 解析不到时返回 nil（调用方退化为不确定进度，不应报错）。
enum ProgressParser {
    private static let regex = try? NSRegularExpression(pattern: #"\d{1,3}\s*%"#)

    static func parseSevenZip(_ line: String) -> Double? { percent(in: line) }
    static func parseUnrar(_ line: String) -> Double? { percent(in: line) }

    /// 取行内**最后一个**百分比（进度在文件名之前，文件名可能含 `%`）。
    /// 合法范围 0–100，越界视为无效。
    private static func percent(in line: String) -> Double? {
        guard let regex else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.matches(in: line, range: range).last else { return nil }

        let matched = (line as NSString).substring(with: match.range)
        let digits = matched.prefix { $0.isNumber }
        guard let value = Int(digits), (0...100).contains(value) else { return nil }
        return Double(value) / 100.0
    }
}
