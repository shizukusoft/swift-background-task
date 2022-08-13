//
//  ProcessInfo+BackgroundTask.swift
//  
//
//  Created by Jaehong Kang on 2022/05/29.
//

#if os(iOS) || os(watchOS) || os(tvOS)

import Foundation
import UnifiedLogging
import os

extension ProcessInfo {
    public struct TaskAssertionError: Error {
        public init() {}
    }
}

extension ProcessInfo {
    private static let log = OSLog(subsystem: moduleIdentifier, category: String(reflecting: ProcessInfo.self))

    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    private static let logger = Logger(log)

    private static func log(level: OSLogType, identifier: String, _ message: String) {
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            logger.log(level: level, "\(identifier, privacy: .public): \(message, privacy: .public)")
        } else {
            os_log("%{public}@: %{public}@", log: log, type: level, identifier, message)
        }
    }
}

extension ProcessInfo {
    private actor ExpiringActivity<Success: Sendable, Failure: Error> {
        var taskAssertionResult: Result<Task<Success, Failure>, TaskAssertionError>?

        func run<T>(
            resultType: T.Type = T.self,
            body: @Sendable (isolated ExpiringActivity<Success, Failure>) throws -> T
        ) async rethrows -> T where T: Sendable {
            try body(self)
        }
    }

    public func performExpiringActivity<T>(reason: String, body: @escaping () async throws -> T) async throws -> T {
        let taskPriority = Task.currentPriority

        let task: Task<T, Error> = try await withCheckedThrowingContinuation { continuation in
            let expiringActivity = ExpiringActivity<T, Error>()

            ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
                Task {
                    let taskToWait: Task<T, Error>? = await expiringActivity.run { expiringActivity in
                        switch (expiringActivity.taskAssertionResult, expired) {
                        case (nil, true):
                            Self.log(level: .warning, identifier: reason, "Task assertion failed.")

                            let error = TaskAssertionError()

                            expiringActivity.taskAssertionResult = .failure(error)
                            continuation.resume(throwing: error)

                            return nil
                        case (nil, false):
                            let task = Task<T, Error>(priority: taskPriority) {
                                Self.log(level: .info, identifier: reason, "Start expiring activity")
                                defer {
                                    Self.log(level: .info, identifier: reason, "Expiring activity finished")
                                }

                                return try await body()
                            }

                            expiringActivity.taskAssertionResult = .success(task)
                            continuation.resume(returning: task)

                            return task
                        case (.some(.success(let task)), true):
                            Self.log(level: .notice, identifier: reason, "Expiring activity expired")

                            task.cancel()

                            return task
                        case (.some(.failure), true):
                            Self.log(level: .notice, identifier: reason, "Expiring activity expired without task")

                            return nil
                        case (.some, false):
                            fatalError()
                        }
                    }

                    await taskToWait?.waitUntilFinished()
                }.waitUntilFinished()
            }
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

#endif
