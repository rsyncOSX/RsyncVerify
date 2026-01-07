//
//  InterruptProcess.swift
//  RsyncVerify
//

import Foundation

@MainActor
struct InterruptProcess {
    @discardableResult
    init() {
        Task {
            SharedReference.shared.process?.interrupt()
            SharedReference.shared.process = nil
        }
    }
}
