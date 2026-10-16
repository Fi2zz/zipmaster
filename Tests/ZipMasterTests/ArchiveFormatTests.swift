import XCTest
@testable import ZipMaster

final class ArchiveFormatTests: XCTestCase {
    func testFileExtensions() {
        XCTAssertEqual(ArchiveFormat.zip.fileExtension, "zip")
        XCTAssertEqual(ArchiveFormat.sevenZip.fileExtension, "7z")
        XCTAssertEqual(ArchiveFormat.tar.fileExtension, "tar")
        XCTAssertEqual(ArchiveFormat.gzip.fileExtension, "gz")
        XCTAssertEqual(ArchiveFormat.bzip2.fileExtension, "bz2")
        XCTAssertEqual(ArchiveFormat.xz.fileExtension, "xz")
    }

    func testSevenZipFlags() {
        XCTAssertEqual(ArchiveFormat.zip.sevenZipFlag, "-tzip")
        XCTAssertEqual(ArchiveFormat.sevenZip.sevenZipFlag, "-t7z")
        XCTAssertEqual(ArchiveFormat.tar.sevenZipFlag, "-ttar")
        XCTAssertEqual(ArchiveFormat.gzip.sevenZipFlag, "-tgzip")
        XCTAssertEqual(ArchiveFormat.bzip2.sevenZipFlag, "-tbzip2")
        XCTAssertEqual(ArchiveFormat.xz.sevenZipFlag, "-txz")
    }

    func testAllCases() {
        XCTAssertEqual(ArchiveFormat.allCases.count, 6)
    }
}
