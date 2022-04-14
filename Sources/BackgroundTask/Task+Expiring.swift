//
//  Task+Expiring.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

import Foundation

extension Task {
    private class Expiration {
        private let dispatchSemaphore = DispatchSemaphore(value: 0)
        var task: Task?

        func expire() {
            guard let task = task else { return }

            task.cancel()
            dispatchSemaphore.wait()
        }

        func finish() {
            dispatchSemaphore.signal()
        }
    }
}

extension Task where Failure == Never {
    @discardableResult
    public static func expiring(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable (@escaping () -> Void) async -> Success
    ) -> Task<Success, Failure> {
        let expiration = Expiration()

        let task = Task(priority: priority) {
            defer {
                expiration.finish()
            }

            return await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }

    @discardableResult
    public static func expiringDetached(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable (@escaping () -> Void) async -> Success
    ) -> Task<Success, Failure> {
        let expiration = Expiration()

        let task = Task.detached(priority: priority) {
            defer {
                expiration.finish()
            }

            return await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }
}

extension Task where Failure == Error {
    @discardableResult
    public static func expiring(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable (@escaping () -> Void) async throws -> Success
    ) -> Task<Success, Failure> {
        let expiration = Expiration()

        let task = Task(priority: priority) {
            defer {
                expiration.finish()
            }

            return try await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }

    @discardableResult
    public static func expiringDetached(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable (@escaping () -> Void) async throws -> Success
    ) -> Task<Success, Failure> {
        let expiration = Expiration()

        let task = Task.detached(priority: priority) {
            defer {
                expiration.finish()
            }

            return try await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }
}
