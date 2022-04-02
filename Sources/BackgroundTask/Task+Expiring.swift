//
//  Task+Expiring.swift
//
//
//  Created by Jaehong Kang on 2022/04/02.
//

import Foundation

extension Task {
    private class Expiration {
        let dispatchGroup = DispatchGroup()
        var task: Task?

        func expire() {
            if let task = task {
                task.cancel()
            }

            dispatchGroup.wait()
        }
    }
}

extension Task where Failure == Never {
    public static func expiring(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async -> Success) -> Task<Success, Failure> {
        let expiration = Expiration()
        expiration.dispatchGroup.enter()

        let task = Task(priority: priority) {
            defer {
                expiration.dispatchGroup.leave()
            }

            return await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }

    public static func expiringDetached(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async -> Success) -> Task<Success, Failure> {
        let expiration = Expiration()
        expiration.dispatchGroup.enter()

        let task = Task.detached(priority: priority) {
            defer {
                expiration.dispatchGroup.leave()
            }

            return await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }
}

extension Task where Failure == Error {
    public static func expiring(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async throws -> Success) -> Task<Success, Failure> {
        let expiration = Expiration()
        expiration.dispatchGroup.enter()

        let task = Task(priority: priority) {
            defer {
                expiration.dispatchGroup.leave()
            }

            return try await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }

    public static func expiringDetached(priority: TaskPriority? = nil, operation: @escaping @Sendable (@escaping () -> Void) async throws -> Success) -> Task<Success, Failure> {
        let expiration = Expiration()
        expiration.dispatchGroup.enter()

        let task = Task.detached(priority: priority) {
            defer {
                expiration.dispatchGroup.leave()
            }

            return try await operation(expiration.expire)
        }

        expiration.task = task

        return task
    }
}
