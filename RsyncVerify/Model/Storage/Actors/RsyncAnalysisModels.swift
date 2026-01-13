//
//  RsyncAnalysisModels.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import Foundation

// MARK: - Rsync Analysis Data Models

extension ActorRsyncOutputAnalyzer {
    struct AnalysisResult {
        let itemizedChanges: [ItemizedChange]
        let statistics: Statistics
        let isDryRun: Bool
    }

    struct ItemizedChange {
        let changeType: ChangeType
        let path: String
        let target: String? // For symlinks
        let flags: ChangeFlags
    }

    enum ChangeType: String {
        case symlink = "L"
        case directory = "d"
        case file = "f"
        case device = "D"
        case special = "S"
        case unknown = "?"
    }

    struct ChangeFlags {
        let fileType: String
        let checksum: Bool // c
        let size: Bool // s
        let timestamp: Bool // t
        let permissions: Bool // p
        let owner: Bool // o
        let group: Bool // g
        let acl: Bool // a
        let xattr: Bool // x

        init(from flagString: String) {
            // Format: . L...p......
            fileType = String(flagString.prefix(2))
            checksum = flagString.contains("c")
            size = flagString.contains("s")
            timestamp = flagString.contains("t")
            permissions = flagString.contains("p")
            owner = flagString.contains("o")
            group = flagString.contains("g")
            acl = flagString.contains("a")
            xattr = flagString.contains("x")
        }
    }

    struct Statistics {
        let totalFiles: FileCount
        let filesCreated: FileCount
        let filesDeleted: Int
        let regularFilesTransferred: Int
        let totalFileSize: Int64
        let totalTransferredSize: Int64
        let literalData: Int64
        let matchedData: Int64
        let bytesSent: Int64
        let bytesReceived: Int64
        let speedup: Double
    }

    struct FileCount {
        let total: Int
        let regular: Int
        let directories: Int
        let links: Int
    }
}
