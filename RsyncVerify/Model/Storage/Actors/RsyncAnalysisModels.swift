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
        let errors: [String]
        let warnings: [String]
        
        init(itemizedChanges: [ItemizedChange],
             statistics: Statistics,
             isDryRun: Bool,
             errors: [String] = [],
             warnings: [String] = []) {
            self.itemizedChanges = itemizedChanges
            self.statistics = statistics
            self.isDryRun = isDryRun
            self.errors = errors
            self.warnings = warnings
        }
    }

    struct ItemizedChange {
        let changeType: ChangeType
        let path: String
        let target: String? // For symlinks
        let flags: ChangeFlags
        
        init(changeType: ChangeType,
             path: String,
             target: String? = nil,
             flags: ChangeFlags = .none) {
            self.changeType = changeType
            self.path = path
            self.target = target
            self.flags = flags
        }
    }

    enum ChangeType: String, CaseIterable {
        case symlink = "L"
        case directory = "d"
        case file = "f"
        case device = "D"
        case special = "S"
        case deletion = "*deleting"
        case unknown = "?"
        
        var description: String {
            switch self {
            case .symlink: return "Symlink"
            case .directory: return "Directory"
            case .file: return "File"
            case .device: return "Device"
            case .special: return "Special"
            case .deletion: return "Deletion"
            case .unknown: return "Unknown"
            }
        }
        
        static func fromFlag(_ flag: String) -> ChangeType {
            if flag.contains("L") { return .symlink }
            if flag.contains("d") { return .directory }
            if flag.contains("f") { return .file }
            if flag.contains("D") { return .device }
            if flag.contains("S") { return .special }
            if flag == "*deleting" { return .deletion }
            return .unknown
        }
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
        let isDeletion: Bool
        
        init(from flagString: String = "") {
            // Format: . L...p...... or *deleting
            if flagString.hasPrefix("*deleting") {
                self.fileType = ""
                self.checksum = false
                self.size = false
                self.timestamp = false
                self.permissions = false
                self.owner = false
                self.group = false
                self.acl = false
                self.xattr = false
                self.isDeletion = true
            } else {
                let cleanFlag = flagString.trimmingCharacters(in: .whitespaces)
                self.fileType = cleanFlag.count >= 2 ? String(cleanFlag.prefix(2)) : ""
                self.checksum = cleanFlag.contains("c")
                self.size = cleanFlag.contains("s")
                self.timestamp = cleanFlag.contains("t")
                self.permissions = cleanFlag.contains("p")
                self.owner = cleanFlag.contains("o")
                self.group = cleanFlag.contains("g")
                self.acl = cleanFlag.contains("a")
                self.xattr = cleanFlag.contains("x")
                self.isDeletion = false
            }
        }
        
        init(isDeletion: Bool = false) {
            self.fileType = ""
            self.checksum = false
            self.size = false
            self.timestamp = false
            self.permissions = false
            self.owner = false
            self.group = false
            self.acl = false
            self.xattr = false
            self.isDeletion = isDeletion
        }
        
        static let none = ChangeFlags(isDeletion: false)
        
        init() {
            self.init(isDeletion: false)
        }
        
        var description: String {
            var flags: [String] = []
            if checksum { flags.append("checksum") }
            if size { flags.append("size") }
            if timestamp { flags.append("timestamp") }
            if permissions { flags.append("permissions") }
            if owner { flags.append("owner") }
            if group { flags.append("group") }
            if acl { flags.append("acl") }
            if xattr { flags.append("xattr") }
            if isDeletion { flags.append("deletion") }
            return flags.isEmpty ? "none" : flags.joined(separator: ", ")
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
        let errors: [String]
        let warnings: [String]
        
        init(totalFiles: FileCount,
             filesCreated: FileCount,
             filesDeleted: Int,
             regularFilesTransferred: Int,
             totalFileSize: Int64,
             totalTransferredSize: Int64,
             literalData: Int64,
             matchedData: Int64,
             bytesSent: Int64,
             bytesReceived: Int64,
             speedup: Double,
             errors: [String] = [],
             warnings: [String] = []) {
            self.totalFiles = totalFiles
            self.filesCreated = filesCreated
            self.filesDeleted = filesDeleted
            self.regularFilesTransferred = regularFilesTransferred
            self.totalFileSize = totalFileSize
            self.totalTransferredSize = totalTransferredSize
            self.literalData = literalData
            self.matchedData = matchedData
            self.bytesSent = bytesSent
            self.bytesReceived = bytesReceived
            self.speedup = speedup
            self.errors = errors
            self.warnings = warnings
        }
        
        var totalFilesChanged: Int {
            return filesCreated.total + filesDeleted
        }
        
        var efficiencyPercentage: Double {
            guard totalFileSize > 0 else { return 0 }
            return (Double(totalTransferredSize) / Double(totalFileSize)) * 100.0
        }
    }

    struct FileCount: CustomStringConvertible {
        let total: Int
        let regular: Int
        let directories: Int
        let links: Int
        
        init(total: Int, regular: Int, directories: Int, links: Int) {
            self.total = total
            self.regular = regular
            self.directories = directories
            self.links = links
        }
        
        var description: String {
            return "\(total) total (reg: \(regular), dir: \(directories), link: \(links))"
        }
        
        static var zero: FileCount {
            return FileCount(total: 0, regular: 0, directories: 0, links: 0)
        }
    }
}

// MARK: - Additional Convenience Extensions

extension ActorRsyncOutputAnalyzer.ItemizedChange: CustomStringConvertible {
    var description: String {
        var result = "\(changeType.description): \(path)"
        if let target = target {
            result += " -> \(target)"
        }
        if !flags.description.isEmpty && flags.description != "none" {
            result += " [\(flags.description)]"
        }
        return result
    }
}

extension ActorRsyncOutputAnalyzer.Statistics: CustomStringConvertible {
    var description: String {
        var result = """
        📊 Statistics:
          Total files: \(totalFiles)
          Created: \(filesCreated)
          Deleted: \(filesDeleted)
          Transferred: \(regularFilesTransferred)
          
        💾 Data Transfer:
          Total size: \(ActorRsyncOutputAnalyzer.formatBytes(totalFileSize))
          Transferred: \(ActorRsyncOutputAnalyzer.formatBytes(totalTransferredSize))
          Efficiency: \(String(format: "%.2f", efficiencyPercentage))%
          Speedup: \(String(format: "%.2f", speedup))x
          
        📊 Transfer Details:
          Literal data: \(ActorRsyncOutputAnalyzer.formatBytes(literalData))
          Matched data: \(ActorRsyncOutputAnalyzer.formatBytes(matchedData))
          Sent: \(ActorRsyncOutputAnalyzer.formatBytes(bytesSent))
          Received: \(ActorRsyncOutputAnalyzer.formatBytes(bytesReceived))
        """
        
        if !errors.isEmpty {
            result += "\n❌ Errors: \(errors.count)"
        }
        if !warnings.isEmpty {
            result += "\n⚠️ Warnings: \(warnings.count)"
        }
        
        return result
    }
}

extension ActorRsyncOutputAnalyzer.ChangeFlags {
    var flagString: String {
        var flags = fileType
        if checksum { flags += "c" }
        if size { flags += "s" }
        if timestamp { flags += "t" }
        if permissions { flags += "p" }
        if owner { flags += "o" }
        if group { flags += "g" }
        if acl { flags += "a" }
        if xattr { flags += "x" }
        return flags
    }
}

// MARK: - Helper Methods

extension ActorRsyncOutputAnalyzer {
    func summary(for result: AnalysisResult) -> String {
        var summary = """
        ════════════════════════════
        RSYNC ANALYSIS SUMMARY
        ════════════════════════════
        
        Run Type: \(result.isDryRun ? "DRY RUN (simulation)" : "LIVE RUN")
        """
        
        if result.isDryRun {
            summary += "\n⚠️  No actual changes were made\n"
        }
        
        summary += """
        
        📈 Summary:
          • Total items: \(result.itemizedChanges.count)
          • Files created: \(result.statistics.filesCreated.total)
          • Files deleted: \(result.statistics.filesDeleted)
          • Data efficiency: \(String(format: "%.1f", result.statistics.efficiencyPercentage))%
          • Transfer speedup: \(String(format: "%.1f", result.statistics.speedup))x
        """
        
        if !result.errors.isEmpty {
            summary += "\n\n❌ Found \(result.errors.count) error(s)"
        }
        
        if !result.warnings.isEmpty {
            summary += "\n⚠️  Found \(result.warnings.count) warning(s)"
        }
        
        return summary
    }
    
    func changesByType(for result: AnalysisResult) -> [ChangeType: Int] {
        var counts: [ChangeType: Int] = [:]
        for change in result.itemizedChanges {
            counts[change.changeType, default: 0] += 1
        }
        return counts
    }
}

