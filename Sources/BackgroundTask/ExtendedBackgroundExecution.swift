//
//  ExtendedBackgroundExecution.swift
//  
//
//  Created by Jaehong Kang on 2022/04/02.
//

import Dispatch
import UnifiedLogging
#if canImport(os)
import os
#endif
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Foundation
#endif

public struct TaskAssertionError: Error {
    public init() {}
}

struct ExtendedBackgroundExecution {
    #if canImport(os)
    static let log = OSLog(subsystem: moduleIdentifier, category: "extended-background-execution")

    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    static let logger = Logger(log)
    #else
    static let logger = Logger(subsystem: moduleIdentifier, category: "extended-background-execution")
    #endif

    #if canImport(os)
    static func log(level: OSLogType, identifier: String, _ message: String) {
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            logger.log(level: level, "\(identifier, privacy: .public): \(message, privacy: .public)")
        } else {
            os_log("%{public}@: %{public}@", log: log, type: level, identifier, message)
        }
    }
    #else
    static func log(level: Logger.LogLevel, identifier: String, _ message: String) {
        logger.log(level: level, "\(identifier): \(message)")
    }
    #endif

    static let isInExtendedBackgroundExecutionKey = moduleName + ".IsInExtendedBackgroundExecution"

    @TaskLocal static var isInExtendedBackgroundExecution: Bool = false
}

@inlinable
public func withExtendedBackgroundExecution<T>(
    function: String = #function,
    fileID: String = #fileID,
    line: Int = #line,
    expirationHandler: (@Sendable () -> Void)? = nil,
    body: () throws -> T
) throws -> T {
    try withExtendedBackgroundExecution(identifier: "\(function) (\(fileID):\(line))", expirationHandler: expirationHandler, body: body)
}

public func withExtendedBackgroundExecution<T>(
    identifier: String,
    expirationHandler: (@Sendable () -> Void)? = nil,
    body: () throws -> T
) throws -> T {
    guard
        ExtendedBackgroundExecution.isInExtendedBackgroundExecution == false ||
            Thread.current.threadDictionary.object(forKey: ExtendedBackgroundExecution.isInExtendedBackgroundExecutionKey) == nil
    else {
        return try body()
    }

    Thread.current.threadDictionary.setValue(true, forKey: ExtendedBackgroundExecution.isInExtendedBackgroundExecutionKey)
    defer {
        Thread.current.threadDictionary.removeObject(forKey: ExtendedBackgroundExecution.isInExtendedBackgroundExecutionKey)
    }

    #if os(macOS)
    let token = ProcessInfo.processInfo.beginActivity(
        options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled],
        reason: identifier
    )
    defer {
        ProcessInfo.processInfo.endActivity(token)
    }

    return try body()
    #elseif os(iOS) || os(watchOS) || os(tvOS)
    let activitySemaphore = DispatchSemaphore(value: 0)
    defer {
        activitySemaphore.signal()
    }

    let taskAssertionSemaphore = DispatchSemaphore(value: 0)
    var isTaskAsserted: Bool = false

    ProcessInfo.processInfo.performExpiringActivity(withReason: identifier) { expired in
        isTaskAsserted = !expired
        taskAssertionSemaphore.signal()

        if expired {
            ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Expiring activity expired")
            expirationHandler?()
            ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Expiring activity expirationHandler finished")
        } else {
            ExtendedBackgroundExecution.log(level: .info, identifier: identifier, "Start expiring activity")
            activitySemaphore.wait()
            ExtendedBackgroundExecution.log(level: .info, identifier: identifier, "Expiring activity finished")
        }
    }

    taskAssertionSemaphore.wait()

    guard isTaskAsserted else {
        throw TaskAssertionError()
    }

    ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Start")
    defer {
        ExtendedBackgroundExecution.log(level: .default, identifier: identifier, "Finished with cancelled: \(Task.isCancelled)")
    }

    return try body()
    #else
    return try body()
    #endif
}
