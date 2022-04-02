//
//  ExpiringTask.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

@preconcurrency import Dispatch
import Foundation

public struct ExpiringTask<Success, Failure>: Sendable where Success: Sendable, Failure: Error {
    private class Expiration {
        var expiringTask: ExpiringTask<Success, Failure>?

        func expire() {
            guard let expiringTask = expiringTask else { return }

            Task.detached {
                expiringTask.cancel()
            }

            expiringTask.dispatchGroup.wait()
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
    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async -> Success) {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        dispatchGroup.enter()
        self.init(
            dispatchGroup: dispatchGroup,
            task: Task(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return await operation(expiration.expire)
            }
        )

        expiration.expiringTask = self
    }

    @discardableResult
    public static func detached(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async -> Success) -> ExpiringTask<Success, Failure> {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        dispatchGroup.enter()
        let expiringTask = self.init(
            dispatchGroup: dispatchGroup,
            task: Task.detached(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return await operation(expiration.expire)
            }
        )

        expiration.expiringTask = expiringTask

        return expiringTask
    }
}

extension ExpiringTask where Failure == Error {
    @discardableResult
    public init(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async throws -> Success) {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        dispatchGroup.enter()
        self.init(
            dispatchGroup: dispatchGroup,
            task: Task(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return try await operation(expiration.expire)
            }
        )

        expiration.expiringTask = self
    }

    @discardableResult
    public static func detached(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async throws -> Success) -> ExpiringTask<Success, Failure> {
        let dispatchGroup = DispatchGroup()
        let expiration = Expiration()

        dispatchGroup.enter()
        let expiringTask = self.init(
            dispatchGroup: dispatchGroup,
            task: Task.detached(priority: priority) {
                defer {
                    dispatchGroup.leave()
                }

                return try await operation(expiration.expire)
            }
        )

        expiration.expiringTask = expiringTask

        return expiringTask
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
