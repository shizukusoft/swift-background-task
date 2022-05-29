//
//  Task+BackgroundTask.swift
//  
//
//  Created by Jaehong Kang on 2022/05/01.
//

import Dispatch

extension Task {
    @inlinable
    public func waitUntilFinished() async {
        _ = try? await value
    }

    @inlinable
    public func waitUntilFinished() {
        let semaphore = DispatchSemaphore(value: 0)

        Task<Void, Never>.detached {
            await waitUntilFinished()
            semaphore.signal()
        }

        semaphore.wait()
    }
}
