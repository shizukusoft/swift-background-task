import XCTest
@testable import BackgroundTask

final class BackgroundTaskTests: XCTestCase {
    func testIsInExtendedBackgroundExecutionValueInTask() async throws {
        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        try await withExtendedBackgroundExecution(priority: .medium) {
            XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, true)
        }

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)
    }
}
