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
    private static let log = OSLog(subsystem: moduleIdentifier, category: "\(moduleName).\(String(reflecting: ProcessInfo.self))")

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
    private class ExpiringActivity {
        private let dispatchQueue = DispatchQueue(
            label: String(reflecting: ExpiringActivity.self),
            qos: .unspecified,
            attributes: [.concurrent],
            autoreleaseFrequency: .inherit,
            target: nil
        )

        private var _isTaskAsserted: Bool?

        var isTaskAsserted: Bool? {
            get {
                dispatchQueue.sync {
                    _isTaskAsserted
                }
            }
            set {
                dispatchQueue.sync(flags: [.barrier]) {
                    _isTaskAsserted = newValue
                }
            }
        }
    }

    public func performExpiringActivity<T>(reason: String, body: @escaping () async throws -> T) async throws -> T {
        let expiringActivity = ExpiringActivity()

        let task: Task<T, Error> = Task {
            while expiringActivity.isTaskAsserted == nil {
                try Task.checkCancellation()
                await Task.yield()
            }

            guard expiringActivity.isTaskAsserted == true else {
                throw TaskAssertionError()
            }

            Self.log(level: .info, identifier: reason, "Start expiring activity")
            defer {
                Self.log(level: .info, identifier: reason, "Expiring activity finished")
            }

            return try await body()
        }

        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            switch (expiringActivity.isTaskAsserted, expired) {
            case (nil, true):
                Self.log(level: .warning, identifier: reason, "Task assertion failed.")
                expiringActivity.isTaskAsserted = false
            case (nil, false):
                expiringActivity.isTaskAsserted = true
                task.waitUntilFinished()
            case (.some, true):
                task.cancel()
            case (.some, false):
                task.waitUntilFinished()
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
