//
//  ProcessInfo+BackgroundTask.swift
//  
//
//  Created by Jaehong Kang on 2022/05/29.
//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

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
    @available(iOS 8.2, tvOS 9.0, watchOS 2.0, *)
    public func performExpiringActivity<T>(reason: String, body: @escaping () async throws -> T) async throws -> T {
        let taskPriority = Task.currentPriority

        let task: Task<T, Error> = try await withCheckedThrowingContinuation { continuation in
            var currentTask: Task<T, Error>?
            let dispatchSemaphore = DispatchSemaphore(value: 1)

            ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
                dispatchSemaphore.wait()

                switch (currentTask, expired) {
                case (nil, true):
                    Self.log(level: .warning, identifier: reason, "Task assertion failed.")

                    dispatchSemaphore.signal()
                    continuation.resume(throwing: TaskAssertionError())
                case (nil, false):
                    Self.log(level: .info, identifier: reason, "Start expiring activity")
                    defer {
                        Self.log(level: .info, identifier: reason, "Expiring activity finished")
                    }

                    let task = Task<T, Error>(priority: taskPriority) {
                        try await body()
                    }

                    currentTask = task
                    dispatchSemaphore.signal()
                    continuation.resume(returning: task)
                    task.waitUntilFinished()
                case (.some(let currentTask), true):
                    Self.log(level: .default, identifier: reason, "Expiring activity expired")
                    defer {
                        Self.log(level: .default, identifier: reason, "Expiring activity expirationHandler finished")
                    }

                    dispatchSemaphore.signal()
                    currentTask.cancel()
                    currentTask.waitUntilFinished()
                default:
                    fatalError()
                }
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
