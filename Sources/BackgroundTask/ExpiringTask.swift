//
//  ExpiringTask.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

import Dispatch
import Foundation

public actor ExpiringTask<Success, Failure>: Sendable where Success: Sendable, Failure: Error {
    private let dispatchGroup = DispatchGroup()
    private var task: Task<Success, Failure>!

    private init() {
        dispatchGroup.enter()
    }

    private convenience init(_ taskHandler: @escaping @Sendable (ExpiringTask) -> Task<Success, Failure>) {
        self.init()

        Task.detached {
            await self.setTask(taskHandler(self))
        }
    }

    private func setTask(_ task: Task<Success, Failure>) {
        self.task = task
    }
}

extension ExpiringTask where Failure == Never {
    public convenience init(priority: TaskPriority? = nil, operation: @escaping @Sendable (ExpiringTask) async -> Success) {
        self.init { expiringTask in
            Task(priority: priority) { [dispatchGroup = expiringTask.dispatchGroup] in
                defer {
                    dispatchGroup.leave()
                }

                return await operation(expiringTask)
            }
        }
    }

    public static func detached(priority: TaskPriority? = nil, operation: @escaping @Sendable (ExpiringTask) async -> Success) -> ExpiringTask<Success, Failure> {
        ExpiringTask { expiringTask in
            Task.detached(priority: priority) { [dispatchGroup = expiringTask.dispatchGroup] in
                defer {
                    dispatchGroup.leave()
                }

                return await operation(expiringTask)
            }
        }
    }
}

extension ExpiringTask where Failure == Error {
    public convenience init(priority: TaskPriority? = nil, operation: @escaping @Sendable (ExpiringTask) async throws -> Success) {
        self.init { expiringTask in
            Task(priority: priority) { [dispatchGroup = expiringTask.dispatchGroup] in
                defer {
                    dispatchGroup.leave()
                }

                return try await operation(expiringTask)
            }
        }
    }

    public static func detached(priority: TaskPriority? = nil, operation: @escaping @Sendable (ExpiringTask) async throws -> Success) -> ExpiringTask<Success, Failure> {
        ExpiringTask { expiringTask in
            Task.detached(priority: priority) { [dispatchGroup = expiringTask.dispatchGroup] in
                defer {
                    dispatchGroup.leave()
                }

                return try await operation(expiringTask)
            }
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
