//
//  Logger.swift
//  
//
//  Created by Jaehong Kang on 2022/04/03.
//

import Foundation
import os

let log = OSLog(subsystem: moduleIdentifier, category: "extended-background-execution")

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
let logger = Logger(log)

func log(identifier: String, level: OSLogType, _ message: String) {
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
        logger.log(level: level, "\(identifier, privacy: .public): \(message, privacy: .public)")
    } else {
        os_log("%{public}@: %{public}@", log: log, type: level, identifier, message)
    }
}
