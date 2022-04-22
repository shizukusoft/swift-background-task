import XCTest
@testable import BackgroundTask

final class BackgroundTaskTests: XCTestCase {
    func testIsInExtendedBackgroundExecutionValueInThread() throws {
        XCTAssertNil(Thread.current.threadDictionary.value(forKey: isInExtendedBackgroundExecutionKey))

        withExtendedBackgroundExecution {
            XCTAssertNotNil(Thread.current.threadDictionary.value(forKey: isInExtendedBackgroundExecutionKey))
        }

        XCTAssertNil(Thread.current.threadDictionary.value(forKey: isInExtendedBackgroundExecutionKey))
    }

    func testIsInExtendedBackgroundExecutionValueInTask() async throws {
        XCTAssertEqual(Task.isInExtendedBackgroundExecution, false)

        await withExtendedBackgroundExecution(priority: .medium) {
            XCTAssertEqual(Task.isInExtendedBackgroundExecution, true)
        }

        XCTAssertEqual(Task.isInExtendedBackgroundExecution, false)
    }
}
