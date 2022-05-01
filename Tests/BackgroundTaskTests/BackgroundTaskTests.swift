import XCTest
@testable import BackgroundTask

final class BackgroundTaskTests: XCTestCase {
    func testIsInExtendedBackgroundExecutionValueInThread() throws {
        XCTAssertNil(Thread.current.threadDictionary.value(forKey: ExtendedBackgroundExecution.isInExtendedBackgroundExecutionKey))

        try withExtendedBackgroundExecution {
            XCTAssertNotNil(Thread.current.threadDictionary.value(forKey: ExtendedBackgroundExecution.isInExtendedBackgroundExecutionKey))
        }

        XCTAssertNil(Thread.current.threadDictionary.value(forKey: ExtendedBackgroundExecution.isInExtendedBackgroundExecutionKey))
    }

    func testIsInExtendedBackgroundExecutionValueInTask() async throws {
        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        try await withExtendedBackgroundExecution(priority: .medium) {
            XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, true)
        }

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)
    }
}
