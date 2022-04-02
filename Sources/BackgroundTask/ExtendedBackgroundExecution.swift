//
//  ExtendedBackgroundExecution.swift
//  
//
//  Created by Jaehong Kang on 2022/04/02.
//

import Foundation
import os

let moduleIdentifier = "com.tweetnest.BackgroundTask"

extension Task where Success == Never, Failure == Never {
    @TaskLocal fileprivate static var isInExtendedBackgroundExecution: Bool = false
}

@Sendable public func withExtendedBackgroundExecution<T>(identifier: String, body: @escaping () async throws -> T) async rethrows -> T {
    guard Task.isInExtendedBackgroundExecution == false else {
        return try await body()
    }

    return try await Task.$isInExtendedBackgroundExecution.withValue(true) {
        if #available(macOS 11.0, *) {
            let logger = Logger(subsystem: moduleIdentifier, category: "extended-background-execution")

            let expiringTask = ExpiringTask {
                try await body()
            }

            #if os(macOS)
            let token = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: identifier)
            defer {
                ProcessInfo.processInfo.endActivity(token)
            }
            #else
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            defer {
                dispatchGroup.leave()
            }

            ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
                if expired {
                    logger.notice("\(identifier, privacy: .public): Expiring activity expired")
                    expiringTask.cancel()
                    logger.notice("\(identifier, privacy: .public): Expiring activity expirationHandler finished")
                } else {
                    logger.info("\(identifier, privacy: .public): Start expiring activity")
                    dispatchGroup.wait()
                    logger.info("\(identifier, privacy: .public): Expiring activity finished")
                }
            }
            #endif

            logger.notice("\(identifier, privacy: .public): Start")
            defer {
                logger.notice("\(identifier, privacy: .public): Finished with cancelled: \(Task.isCancelled)")
            }

            return try await withTaskCancellationHandler {
                try await expiringTask.value
            } onCancel: {
                expiringTask.cancel()
            }
        } else {
            let expiringTask = ExpiringTask {
                try await body()
            }

            #if os(macOS)
            let token = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: identifier)
            defer {
                ProcessInfo.processInfo.endActivity(token)
            }
            #else
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            defer {
                dispatchGroup.leave()
            }

            ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
                if expired {
                    expiringTask.cancel()
                } else {
                    dispatchGroup.wait()
                }
            }
            #endif

            return try await withTaskCancellationHandler {
                try await expiringTask.value
            } onCancel: {
                expiringTask.cancel()
            }
        }
    }
}

@Sendable @inlinable public func withExtendedBackgroundExecution<T>(function: String = #function, fileID: String = #fileID, line: Int = #line, body: @escaping () async throws -> T) async rethrows -> T {
    try await withExtendedBackgroundExecution(identifier: "\(function) (\(fileID):\(line))", body: body)
}
