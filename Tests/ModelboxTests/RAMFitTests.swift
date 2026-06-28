import XCTest
@testable import Modelbox

final class RAMFitTests: XCTestCase {
    func testEstimateScalesBySizeAndFactor() {
        XCTAssertEqual(RAMEstimate.bytes(forModelSize: 1_000_000_000, factor: 1.2), 1_200_000_000)
        XCTAssertEqual(RAMEstimate.bytes(forModelSize: 0, factor: 1.2), 0)
    }

    func testFitsWhenWellUnderRAM() {
        // 5 GB estimate on a 36 GB machine.
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 5_000_000_000, machineRAM: 36_000_000_000), .fits)
    }

    func testTightNearTheLimit() {
        // 30 GB estimate on a 36 GB machine (>70%, <=100%).
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 30_000_000_000, machineRAM: 36_000_000_000), .tight)
    }

    func testTooBigOverRAM() {
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 40_000_000_000, machineRAM: 36_000_000_000), .tooBig)
    }

    func testZeroMachineRAMIsTooBig() {
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 1, machineRAM: 0), .tooBig)
    }

    func testBoundaryAtSeventyPercentFits() {
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 70, machineRAM: 100), .fits)
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 71, machineRAM: 100), .tight)
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 100, machineRAM: 100), .tight)
        XCTAssertEqual(RAMFit.evaluate(estimatedRAM: 101, machineRAM: 100), .tooBig)
    }
}
