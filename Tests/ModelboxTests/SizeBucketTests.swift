import XCTest
@testable import Modelbox

final class SizeBucketTests: XCTestCase {
    func testBillionsParsing() {
        XCTAssertEqual(SizeBucket.billions(from: "8B"), 8)
        XCTAssertEqual(SizeBucket.billions(from: "70B"), 70)
        XCTAssertEqual(SizeBucket.billions(from: "1.5B"), 1.5)
        XCTAssertEqual(SizeBucket.billions(from: "8X7B"), 56) // mixture total
        XCTAssertNil(SizeBucket.billions(from: nil))
        XCTAssertNil(SizeBucket.billions(from: ""))
    }

    func testAnyMatchesEverythingIncludingUnknown() {
        XCTAssertTrue(SizeBucket.any.matches(nil))
        XCTAssertTrue(SizeBucket.any.matches("8B"))
    }

    func testBucketBoundaries() {
        XCTAssertTrue(SizeBucket.small.matches("4B"))
        XCTAssertFalse(SizeBucket.small.matches("8B"))
        XCTAssertTrue(SizeBucket.medium.matches("8B"))
        XCTAssertTrue(SizeBucket.medium.matches("13B"))
        XCTAssertFalse(SizeBucket.medium.matches("34B"))
        XCTAssertTrue(SizeBucket.large.matches("34B"))
        XCTAssertTrue(SizeBucket.extraLarge.matches("70B"))
    }

    func testNonAnyBucketsRejectUnknownSize() {
        XCTAssertFalse(SizeBucket.small.matches(nil))
        XCTAssertFalse(SizeBucket.extraLarge.matches(nil))
    }
}
