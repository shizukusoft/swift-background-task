//
//  ProcessInfo+BackgroundTask.swift
//  
//
//  Created by Jaehong Kang on 2022/05/29.
//

#if os(iOS) || os(watchOS) || os(tvOS)

import Foundation
import UnifiedLogging
import Combine
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
    private actor ExpiringActivity {
        @Published var isTaskAsserted: Bool?

        func run<T>(resultType: T.Type = T.self, body: @Sendable (isolated ExpiringActivity) throws -> T) async rethrows -> T where T : Sendable {
            try body(self)
        }
    }

    public func performExpiringActivity<T>(reason: String, body: @escaping () async throws -> T) async throws -> T {
        let expiringActivity = ExpiringActivity()

        let task: Task<T, Error> = Task {
            if #available(iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
                for await isTaskAsserted in await expiringActivity.$isTaskAsserted.values {
                    guard isTaskAsserted == nil else {
                        break
                    }
                }
            } else {
                while await expiringActivity.isTaskAsserted == nil {
                    try Task.checkCancellation()
                    await Task.yield()
                }
            }

            guard await expiringActivity.isTaskAsserted == true else {
                throw TaskAssertionError()
            }

            Self.log(level: .info, identifier: reason, "Start expiring activity")
            defer {
                Self.log(level: .info, identifier: reason, "Expiring activity finished")
            }

            return try await body()
        }

        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            Task {
                await expiringActivity.run { expiringActivity in
                    switch (expiringActivity.isTaskAsserted, expired) {
                    case (nil, true):
                        Self.log(level: .warning, identifier: reason, "Task assertion failed.")
                        expiringActivity.isTaskAsserted = false
                    case (nil, false):
                        expiringActivity.isTaskAsserted = true
                    case (.some, true):
                        task.cancel()
                    case (.some, false):
                        break
                    }
                }
            }.waitUntilFinished()

            task.waitUntilFinished()
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

#endif
