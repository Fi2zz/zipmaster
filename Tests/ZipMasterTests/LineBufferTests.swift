import XCTest
@testable import ZipMaster

final class LineBufferTests: XCTestCase {
    func testPreservesUTF8SplitAcrossChunks() {
        var lines: [String] = []
        let buffer = LineBuffer { lines.append($0) }
        let bytes = Array("含 空格.txt\n".utf8)

        // 在 3 字节的 '含' 中间切开
        buffer.append(Data(bytes[0..<1]))
        buffer.append(Data(bytes[1...]))

        XCTAssertEqual(lines, ["含 空格.txt"])
    }

    func testBackspaceDelimitsProgressBurst() {
        var lines: [String] = []
        let buffer = LineBuffer { lines.append($0) }
        buffer.append(Data("  0%\u{08}\u{08}\u{08}    \u{08}\u{08}\u{08} 80% 2 + f3.bin\n".utf8))

        let values = lines.compactMap(ProgressParser.parseSevenZip)
        XCTAssertEqual(values.last, 0.80, "lines=\(lines)")
    }
}
