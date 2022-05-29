//
//  ExtendedBackgroundExecution.swift
//  
//
//  Created by Jaehong Kang on 2022/04/02.
//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Foundation
#endif
import UnifiedLogging
#if canImport(os)
import os
#endif

struct ExtendedBackgroundExecution {
    @TaskLocal static var isInExtendedBackgroundExecution: Bool = false
}

extension ExtendedBackgroundExecution {
    #if canImport(os)
    fileprivate static let log = OSLog(subsystem: moduleIdentifier, category: "extended-background-execution")

    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    fileprivate static let logger = Logger(log)
    #else
    fileprivate static let logger = Logger(label: moduleIdentifier, category: "extended-background-execution")
    #endif

    #if canImport(os)
    fileprivate static func log(level: OSLogType, identifier: String, _ message: String) {
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            logger.log(level: level, "\(identifier, privacy: .public): \(message, privacy: .public)")
        } else {
            os_log("%{public}@: %{public}@", log: log, type: level, identifier, message)
        }
    }
    #else
    fileprivate static func log(level: Logger.LogLevel, identifier: String, _ message: String) {
        logger.log(level: level, "\(identifier): \(message)")
    }
    #endif
}

@Sendable
public func withExtendedBackgroundExecution<T>(
    identifier: String,
    priority: TaskPriority? = nil,
    body: @escaping () async throws -> T
) async throws -> T {
    ExtendedBackgroundExecution.log(level: .notice, identifier: identifier, "Start")
    defer {
        ExtendedBackgroundExecution.log(level: .notice, identifier: identifier, "Finished with cancelled: \(Task.isCancelled)")
    }

    guard ExtendedBackgroundExecution.isInExtendedBackgroundExecution == false else {
        return try await body()
    }

    #if os(iOS) || os(watchOS) || os(tvOS)
    return try await ProcessInfo.processInfo.performExpiringActivity(reason: identifier) {
        try await ExtendedBackgroundExecution.$isInExtendedBackgroundExecution.withValue(true) {
            try await body()
        }
    }
    #else
    #if os(macOS)
    let token = ProcessInfo.processInfo.beginActivity(
        options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled],
        reason: identifier
    )
    defer {
        ProcessInfo.processInfo.endActivity(token)
    }
    #endif

    return try await ExtendedBackgroundExecution.$isInExtendedBackgroundExecution.withValue(true) {
        try await body()
    }
    #endif
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
