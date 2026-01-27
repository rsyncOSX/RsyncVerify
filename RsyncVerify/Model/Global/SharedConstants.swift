//
//  SharedConstants.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 29/03/2025.
//

/// Sendable
struct SharedConstants: Sendable {
    /// JSON names
    let fileconfigurationsjson = "configurations.json"
    /// Filename logfile
    let logname: String = "rsyncverify_log.txt"
    /// filsize logfile warning
    /// 1_000_000 Bytes = 1 MB
    let logfilesize: Int = 1_000_000
}
