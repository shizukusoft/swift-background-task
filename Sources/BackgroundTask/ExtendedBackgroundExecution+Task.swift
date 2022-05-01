//
//  ExtendedBackgroundExecution+Task.swift
//  
//
//  Created by Jaehong Kang on 2022/05/01.
//

import Foundation

@Sendable
public func withExtendedBackgroundExecution<T>(
    identifier: String,
    priority: TaskPriority? = nil,
    body: @escaping () async throws -> T
) async throws -> T {
    guard ExtendedBackgroundExecution.isInExtendedBackgroundExecution == false else {
        return try await body()
    }

    return try await ExtendedBackgroundExecution.$isInExtendedBackgroundExecution.withValue(true) {
        #if os(macOS)
        let token = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled],
            reason: identifier
        )
        defer {
            ProcessInfo.processInfo.endActivity(token)
        }

        return try await body()
        #elseif os(iOS) || os(watchOS) || os(tvOS)
        let taskPriority = Task.currentPriority

        let task: Task<T, Error> = try await withCheckedThrowingContinuation { continuation in
            var currentTask: Task<T, Error>?

            ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
                switch (currentTask, expired) {
                case (nil, true):
                    continuation.resume(throwing: TaskAssertionError())
                case (nil, false):
                    ExtendedBackgroundExecution.log(level: .info, identifier: identifier, "Start expiring activity")
                    let task = Task<T, Error>(priority: taskPriority) {
                        ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Start")
                        defer {
                            ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Finished with cancelled: \(Task.isCancelled)")
                        }

                        return try await body()
                    }
                    currentTask = task
                    continuation.resume(returning: task)
                    task.waitUntilFinished()
                    ExtendedBackgroundExecution.log(level: .info, identifier: identifier, "Expiring activity finished")
                case (.some(let currentTask), true):
                    ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Expiring activity expired")
                    currentTask.cancel()
                    currentTask.waitUntilFinished()
                    ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Expiring activity expirationHandler finished")
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
        #else
        return try await body()
        #endif
    }
}

@Sendable @inlinable
public func withExtendedBackgroundExecution<T>(
    function: String = #function,
    fileID: String = #fileID,
    line: Int = #line,
    priority: TaskPriority? = nil,
    body: @escaping () async throws -> T
) async throws -> T {
    try await withExtendedBackgroundExecution(
        identifier: "\(function) (\(fileID):\(line))",
        priority: priority,
        body: body
    )
}
