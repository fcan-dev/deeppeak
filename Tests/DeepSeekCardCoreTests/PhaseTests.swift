import XCTest
@testable import DeepSeekCardCore

final class PhaseTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(Phase.peak.label, "PEAK")
        XCTAssertEqual(Phase.offPeak(.weekday).label, "OFFPEAK")
        XCTAssertEqual(Phase.offPeak(.weekend).label, "OFFPEAK")
        XCTAssertEqual(Phase.offPeak(.chineseHoliday("National Day")).label, "OFFPEAK")
        XCTAssertTrue(Phase.peak.isPeak)
        XCTAssertFalse(Phase.offPeak(.weekend).isPeak)
    }
}
