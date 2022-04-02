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
    @Sendable
    public nonisolated func expire() {
        Task.detached {
            await self.cancel()
        }
        dispatchGroup.wait()
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
    }
}

extension ExpiringTask where Failure == Never {
    public var value: Success {
        get async {
            await task.value
        }
    }
}

extension ExpiringTask: Hashable {
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension ExpiringTask: Equatable {
    public static func == (lhs: ExpiringTask<Success, Failure>, rhs: ExpiringTask<Success, Failure>) -> Bool {
        lhs === rhs
    }
}
