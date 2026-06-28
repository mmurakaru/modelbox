import XCTest
@testable import Modelbox

final class ScanConfigurationTests: XCTestCase {
    func testParseCustomPathsTrimsBlanksAndExpandsTilde() {
        let paths = ScanConfiguration.parseCustomPaths("/a/b ,  , ~/models ,")
        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(paths[0].path, "/a/b")
        XCTAssertFalse(paths[1].path.contains("~"))
        XCTAssertTrue(paths[1].path.hasSuffix("/models"))
    }

    func testEmptyCustomPathsString() {
        XCTAssertTrue(ScanConfiguration.parseCustomPaths("   ").isEmpty)
    }

    func testScannersReflectEnabledSources() {
        let only = ScanConfiguration(ollama: true, huggingFace: false, lmStudio: false,
                                     openWhispr: false, appSupport: false)
        XCTAssertEqual(DefaultScanners.scanners(for: only).map(\.source), [.ollama])
    }

    func testAllDisabledYieldsNoScanners() {
        let none = ScanConfiguration(ollama: false, huggingFace: false, lmStudio: false,
                                     openWhispr: false, appSupport: false)
        XCTAssertTrue(DefaultScanners.scanners(for: none).isEmpty)
    }

    func testCustomPathsAddCustomScanner() {
        let config = ScanConfiguration(ollama: false, huggingFace: false, lmStudio: false,
                                       openWhispr: false, appSupport: false,
                                       customPaths: [URL(fileURLWithPath: "/tmp/models")])
        XCTAssertEqual(DefaultScanners.scanners(for: config).map(\.source), [.custom])
    }

    func testDefaultsEnableAllKnownSources() {
        let sources = Set(DefaultScanners.scanners(for: ScanConfiguration()).map(\.source))
        XCTAssertEqual(sources, [.ollama, .huggingFaceCache, .lmStudio, .openWhispr, .appSupport])
    }
}
