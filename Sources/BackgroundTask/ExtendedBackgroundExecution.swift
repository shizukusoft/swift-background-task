//
//  ExtendedBackgroundExecution.swift
//  
//
//  Created by Jaehong Kang on 2022/04/02.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
import os

fileprivate let log = OSLog(subsystem: moduleIdentifier, category: "extended-background-execution")

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
fileprivate let logger = Logger(log)

fileprivate func log(identifier: String, level: OSLogType, _ message: String) {
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
        logger.log(level: level, "\(identifier, privacy: .public): \(message, privacy: .public)")
    } else {
        os_log("%{public}@: %{public}@", log: log, type: level, identifier, message)
    }
}

extension Task where Success == Never, Failure == Never {
    @TaskLocal fileprivate static var isInExtendedBackgroundExecution: Bool = false
}

@Sendable public func withExtendedBackgroundExecution<T>(identifier: String, priority: TaskPriority? = nil, body: @escaping () async throws -> T) async rethrows -> T {
    guard Task.isInExtendedBackgroundExecution == false else {
        return try await body()
    }

    return try await Task.$isInExtendedBackgroundExecution.withValue(true) {
        let expiringTask = ExpiringTask(priority: priority) { expire -> T in
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

            ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
                if expired {
                    log(identifier: identifier, level: .default, "Expiring activity expired")
                    expire()
                    log(identifier: identifier, level: .default, "Expiring activity expirationHandler finished")
                } else {
                    log(identifier: identifier, level: .info, "Start expiring activity")
                    dispatchGroup.wait()
                    log(identifier: identifier, level: .info, "Expiring activity finished")
                }
            }

            log(identifier: identifier, level: .default, "Start")
            defer {
                log(identifier: identifier, level: .default, "Finished with cancelled: \(Task.isCancelled)")
            }

            return try await body()
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
#endif
