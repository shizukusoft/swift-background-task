//
//  TaskExpiringTests.swift
//  
//
//  Created by 강재홍 on 2022/04/03.
//

import XCTest
@testable import BackgroundTask

class TaskExpiringTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExpire() async throws {
        let taskFinishedExpectation = XCTestExpectation(description: "Task Finished Expectation")
        taskFinishedExpectation.isInverted = true

        let taskEndedExpectation = XCTestExpectation(description: "Task Ended Expectation")

        let taskExpireExpectation = XCTestExpectation(description: "Task Expire Expectation")

        Task.expiring { expire in
            defer {
                taskEndedExpectation.fulfill()
                XCTAssertEqual(Task.isCancelled, true)
            }

            DispatchQueue.global(qos: .default).async {
                expire()
                taskExpireExpectation.fulfill()
            }

            if await Self.doStuff() {
                taskFinishedExpectation.fulfill()
            }
        }

        wait(
            for: [taskEndedExpectation, taskExpireExpectation, taskFinishedExpectation],
            timeout: 10.0,
            enforceOrder: true
        )
    }

    func testCancel() async throws {
        let taskFinishedExpectation = XCTestExpectation(description: "Task Finished Expectation")
        taskFinishedExpectation.isInverted = true

        let taskEndedExpectation = XCTestExpectation(description: "Task Ended Expectation")

        let taskCancelExpectation = XCTestExpectation(description: "Task Cancel Expectation")

        let task = Task.expiring { _ in
            defer {
                taskEndedExpectation.fulfill()
                XCTAssertEqual(Task.isCancelled, true)
            }

            if await Self.doStuff() {
                taskFinishedExpectation.fulfill()
            }
        }

        Task.detached {
            task.cancel()
            taskCancelExpectation.fulfill()
        }

        wait(
            for: [taskCancelExpectation, taskEndedExpectation, taskFinishedExpectation],
            timeout: 10.0,
            enforceOrder: true
        )
    }

    @discardableResult
    private static func doStuff() async -> Bool {
        for value in Int64.min...Int64.max {
            guard Task.isCancelled == false else { return false }

            _ = value
        }

        return true
    }
}
