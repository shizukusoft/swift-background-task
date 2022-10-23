//
//  ExtendedBackgroundExecutionTests.swift
//  
//
//  Created by Jaehong Kang on 2022/08/23.
//

import XCTest
@testable import BackgroundTask

class ExtendedBackgroundExecutionTests: XCTestCase {
    func testExtendedBackgroundExecution() async throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        let timeout = 10.0

        try await withExtendedBackgroundExecution {
            try await Task.sleep(nanoseconds: UInt64(timeout) * NSEC_PER_SEC)

            try Task.checkCancellation()

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    func testAsyncFunc() async throws {
        let expectation = XCTestExpectation()

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        try await withExtendedBackgroundExecution {
            XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, true)
            expectation.fulfill()
        }

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        wait(for: [expectation], timeout: 5.0)
    }

    func testTask() async throws {
        let expectation = XCTestExpectation()

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        Task(priority: .high) {
            do {
                XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

                try await withExtendedBackgroundExecution {
                    XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, true)
                    expectation.fulfill()
                }

                XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        wait(for: [expectation], timeout: 5.0)
    }

    func testTaskDetached() async throws {
        let expectation = XCTestExpectation()

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        Task.detached(priority: .high) {
            do {
                XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

                try await withExtendedBackgroundExecution {
                    XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, true)
                    expectation.fulfill()
                }

                XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        wait(for: [expectation], timeout: 5.0)
    }

    func testWithThrowingTaskGroup() async throws {
        let expectation = XCTestExpectation()

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        try await withThrowingTaskGroup(of: Void.self) { _ in
            XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

            try await withExtendedBackgroundExecution {
                XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, true)
                expectation.fulfill()
            }

            XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)
        }

        XCTAssertEqual(ExtendedBackgroundExecution.isInExtendedBackgroundExecution, false)

        wait(for: [expectation], timeout: 5.0)
    }
}
