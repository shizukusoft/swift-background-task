//
//  ExpiringTask.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

@preconcurrency import Dispatch
import Foundation

public actor ExpiringTask<Success, Failure>: Sendable where Success: Sendable, Failure: Error {
    private let dispatchGroup = DispatchGroup()
    private var task: Task<Success, Failure>!

    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable (ExpiringTask) async -> Success) async where Failure == Never {
        dispatchGroup.enter()
        self.task = Task(priority: priority) { [dispatchGroup] in
            defer {
                dispatchGroup.leave()
            }

            return await operation(self)
        }
    }

    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable (ExpiringTask) async throws -> Success) async where Failure == Error {
        dispatchGroup.enter()
        self.task = Task(priority: priority) { [dispatchGroup] in
            defer {
                dispatchGroup.leave()
            }

            return try await operation(self)
        }
    }
}

extension ExpiringTask {
    public nonisolated var value: Success {
        get async throws {
            try await task.value
        }
    }

    public nonisolated var result: Result<Success, Failure> {
        get async {
            await task.result
        }
    }

    public nonisolated func cancel() {
        Task.detached {
            await self.task.cancel()
        }
        dispatchGroup.wait()
    }
}
