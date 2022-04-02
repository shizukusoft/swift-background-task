//
//  ExtendedBackgroundExecution.swift
//  
//
//  Created by Jaehong Kang on 2022/04/02.
//

import Foundation
#if !os(macOS)
import os
#endif

let moduleIdentifier = "com.tweetnest.BackgroundTask"

extension Task where Success == Never, Failure == Never {
    @TaskLocal fileprivate static var isInExtendedBackgroundExecution: Bool = false
}

@Sendable public func withExtendedBackgroundExecution<T>(identifier: String, priority: TaskPriority? = nil, body: @escaping () async throws -> T) async rethrows -> T {
    guard Task.isInExtendedBackgroundExecution == false else {
        return try await body()
    }

    return try await Task.$isInExtendedBackgroundExecution.withValue(true) {
        let expiringTask = await ExpiringTask(priority: priority) { task -> T in
            #if os(macOS)
            let token = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: identifier)
            defer {
                ProcessInfo.processInfo.endActivity(token)
            }

            return try await body()
            #else
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            defer {
                dispatchGroup.leave()
            }

            if #available(iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                let logger = Logger(subsystem: moduleIdentifier, category: "extended-background-execution")

                ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
                    if expired {
                        logger.notice("\(identifier, privacy: .public): Expiring activity expired")
                        task.cancel()
                        logger.notice("\(identifier, privacy: .public): Expiring activity expirationHandler finished")
                    } else {
                        logger.info("\(identifier, privacy: .public): Start expiring activity")
                        dispatchGroup.wait()
                        logger.info("\(identifier, privacy: .public): Expiring activity finished")
                    }
                }

                logger.notice("\(identifier, privacy: .public): Start")
                defer {
                    logger.notice("\(identifier, privacy: .public): Finished with cancelled: \(Task.isCancelled)")
                }

                return try await body()
            } else {
                ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
                    if expired {
                        task.cancel()
                    } else {
                        dispatchGroup.wait()
                    }
                }

                return try await body()
            }
            #endif
        }

        return try await withTaskCancellationHandler {
            try await expiringTask.value
        } onCancel: {
            expiringTask.cancel()
        }
    }
}

@Sendable @inlinable public func withExtendedBackgroundExecution<T>(function: String = #function, fileID: String = #fileID, line: Int = #line, priority: TaskPriority? = nil, body: @escaping () async throws -> T) async rethrows -> T {
    try await withExtendedBackgroundExecution(identifier: "\(function) (\(fileID):\(line))", priority: priority, body: body)
}
