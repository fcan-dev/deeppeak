import XCTest
@testable import DeepPeakCore

final class PhaseTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(Phase.peak.label, "PEAK")
        XCTAssertEqual(Phase.offPeak(.weekday).label, "OFFPEAK")
        XCTAssertEqual(Phase.offPeak(.weekend).label, "OFFPEAK")
        XCTAssertEqual(Phase.offPeak(.chineseHoliday("National Day")).label, "OFFPEAK")
        XCTAssertTrue(Phase.peak.isPeak)
        XCTAssertFalse(Phase.offPeak(.weekend).isPeak)
    }

    func testIndicatorColors() {
        XCTAssertEqual(Phase.peak.indicatorColor, .red)
        XCTAssertEqual(Phase.offPeak(.weekday).indicatorColor, .green)
        XCTAssertEqual(Phase.offPeak(.weekend).indicatorColor, .darkGreen)
        XCTAssertEqual(Phase.offPeak(.chineseHoliday("National Day")).indicatorColor, .blue)
        XCTAssertEqual(Phase.offPeak(.chineseHoliday("Anything")).indicatorColor, .blue)
    }
}
