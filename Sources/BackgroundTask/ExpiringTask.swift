//
//  ExpiringTask.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

@preconcurrency import Dispatch
import Foundation

public struct ExpiringTask<Success, Failure>: Sendable where Success: Sendable, Failure: Error {
    private let dispatchGroup = DispatchGroup()
    private var task: Task<Success, Failure>!
}

extension ExpiringTask where Failure == Never {
    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable () async -> Success) {
        self.init()

        dispatchGroup.enter()
        self.task = Task(priority: priority) { [dispatchGroup] in
            defer {
                dispatchGroup.leave()
            }

            return await operation()
        }
    }
}

extension ExpiringTask where Failure == Error {
    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Success) {
        self.init()

        dispatchGroup.enter()
        self.task = Task(priority: priority) { [dispatchGroup] in
            defer {
                dispatchGroup.leave()
            }

            return try await operation()
        }
    }
}

extension ExpiringTask {
    public var value: Success {
        get async throws {
            try await task.value
        }
    }
    public var result: Result<Success, Failure> {
        get async {
            await task.result
        }
    }

    public func cancel() {
        task.cancel()
        dispatchGroup.wait()
    }
}
