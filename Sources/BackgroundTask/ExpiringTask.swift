//
//  ExpiringTask.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

@preconcurrency import Dispatch
import Foundation

public struct ExpiringTask<Success, Failure>: Sendable where Success: Sendable, Failure: Error {
    public actor Expiration {
        fileprivate var expiringTask: ExpiringTask<Success, Failure>?

        public func callAsFunction() {
            expiringTask?.expire()
        }

        fileprivate func setExpiringTask(_ expiringTask: ExpiringTask<Success, Failure>) {
            self.expiringTask = expiringTask
        }
    }

    private let dispatchGroup: DispatchGroup
    private let task: Task<Success, Failure>

    private init(dispatchGroup: DispatchGroup, task: Task<Success, Failure>) {
        self.dispatchGroup = dispatchGroup
        self.task = task
    }
}

extension ExpiringTask where Failure == Never {
    @discardableResult
    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable (Expiration) async -> Success) {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        self.init(
            dispatchGroup: dispatchGroup,
            task: Task(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return await operation(expiration)
            }
        )

        Task.detached { [self] in
            await expiration.setExpiringTask(self)
        }
    }

    @discardableResult
    public static func detached(priority: TaskPriority? = nil, operation: @escaping @Sendable (Expiration) async -> Success) -> ExpiringTask<Success, Failure> {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        let expiringTask = self.init(
            dispatchGroup: dispatchGroup,
            task: Task.detached(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return await operation(expiration)
            }
        )

        Task.detached {
            await expiration.setExpiringTask(expiringTask)
        }

        return expiringTask
    }
}

extension ExpiringTask where Failure == Error {
    @discardableResult
    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable (Expiration) async throws -> Success) {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        self.init(
            dispatchGroup: dispatchGroup,
            task: Task(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return try await operation(expiration)
            }
        )

        Task.detached { [self] in
            await expiration.setExpiringTask(self)
        }
    }

    @discardableResult
    public static func detached(priority: TaskPriority? = nil, operation: @escaping @Sendable (Expiration) async throws -> Success) -> ExpiringTask<Success, Failure> {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        let expiringTask = self.init(
            dispatchGroup: dispatchGroup,
            task: Task.detached(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return try await operation(expiration)
            }
        )

        Task.detached {
            await expiration.setExpiringTask(expiringTask)
        }

        return expiringTask
    }
}

extension ExpiringTask {
    @Sendable
    public nonisolated func expire() {
        Task.detached {
        self.cancel()
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

extension ExpiringTask: Hashable { }
extension ExpiringTask: Equatable { }
