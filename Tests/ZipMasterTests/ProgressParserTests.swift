import XCTest
@testable import ZipMaster

final class ProgressParserTests: XCTestCase {
    func testSevenZipMidpoint() {
        XCTAssertEqual(ProgressParser.parseSevenZip(" 45% 12 - file.txt"), 0.45)
    }

    func testSevenZipZeroAndHundred() {
        XCTAssertEqual(ProgressParser.parseSevenZip("  0% 1 + a"), 0.0)
        XCTAssertEqual(ProgressParser.parseSevenZip("100% 12 - file.txt"), 1.0)
    }

    func testSevenZipNoPercentageReturnsNil() {
        XCTAssertNil(ProgressParser.parseSevenZip("Extracting foo"))
        XCTAssertNil(ProgressParser.parseSevenZip(""))
    }

    func testUnrarProgress() {
        XCTAssertEqual(ProgressParser.parseUnrar("Extracting  file               50%"), 0.5)
        XCTAssertEqual(ProgressParser.parseUnrar("50%"), 0.5)
    }

    func testUnrarNoPercentageReturnsNil() {
        XCTAssertNil(ProgressParser.parseUnrar("All OK"))
    }

    func testClampsOutOfRange() {
        XCTAssertNil(ProgressParser.parseSevenZip("999% x"))
    }

    func testParsesLastPercentageInLine() {
        XCTAssertEqual(ProgressParser.parseSevenZip("  0% then 80%"), 0.8)
    }
}
