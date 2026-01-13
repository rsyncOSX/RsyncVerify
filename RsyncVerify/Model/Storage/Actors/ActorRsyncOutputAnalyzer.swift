//
//  ActorRsyncOutputAnalyzer.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 11/01/2026.
//

import Foundation

actor ActorRsyncOutputAnalyzer {
    // MARK: - Data Models

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

    // MARK: - Main Analysis Function

    func analyze(_ output: String) -> AnalysisResult? {
        let lines = output.components(separatedBy: .newlines)

        var itemizedChanges: [ItemizedChange] = []
        var statsLines: [String] = []
        var parsingStats = false

        for line in lines {
            if line.hasPrefix("Number of files: ") {
                parsingStats = true
            }

            if parsingStats {
                statsLines.append(line)
            } else if !line.isEmpty, !line.hasPrefix("sending incremental") {
                if let change = parseItemizedChange(line) {
                    itemizedChanges.append(change)
                }
            }
        }

        guard let statistics = parseStatistics(statsLines) else {
            return nil
        }

        let isDryRun = output.contains("(DRY RUN)")

        return AnalysisResult(
            itemizedChanges: itemizedChanges,
            statistics: statistics,
            isDryRun: isDryRun
        )
    }

    func analyze(_ output: [RsyncOutputData]) -> AnalysisResult? {
        guard !output.isEmpty else { return nil }
        let stringdata = output.map { record in
            record.record
        }
        let output = stringdata.joined(separator: "\n")
        let lines = output.components(separatedBy: .newlines)

        var itemizedChanges: [ItemizedChange] = []
        var statsLines: [String] = []
        var parsingStats = false

        for line in lines {
            if line.hasPrefix("Number of files: ") {
                parsingStats = true
            }

            if parsingStats {
                statsLines.append(line)
            } else if !line.isEmpty, !line.hasPrefix("sending incremental") {
                if let change = parseItemizedChange(line) {
                    itemizedChanges.append(change)
                }
            }
        }

        guard let statistics = parseStatistics(statsLines) else {
            return nil
        }

        let isDryRun = output.contains("(DRY RUN)")

        return AnalysisResult(
            itemizedChanges: itemizedChanges,
            statistics: statistics,
            isDryRun: isDryRun
        )
    }

    // MARK: - Parsing Functions

    private func parseItemizedChange(_ line: String) -> ItemizedChange? {
        // Pattern: .L...p.. .... path -> target
        // or:  <f.st... .... path

        let components = line.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard components.count >= 2 else { return nil }

        let flagString = components[0]
        let changeType = parseChangeType(flagString)
        let flags = ChangeFlags(from: flagString)

        // Check if it's a symlink with arrow
        if let arrowIndex = components.firstIndex(of: "->") {
            let path = components[1 ..< arrowIndex].joined(separator: " ")
            let target = components[(arrowIndex + 1)...].joined(separator: " ")
            return ItemizedChange(
                changeType: changeType,
                path: path,
                target: target,
                flags: flags
            )
        } else {
            let path = components[1...].joined(separator: " ")
            return ItemizedChange(
                changeType: changeType,
                path: path,
                target: nil,
                flags: flags
            )
        }
    }

    private func parseChangeType(_ flagString: String) -> ChangeType {
        if flagString.contains("L") { return .symlink }
        if flagString.contains("d") { return .directory }
        if flagString.contains("f") { return .file }
        if flagString.contains("D") { return .device }
        if flagString.contains("S") { return .special }
        return .unknown
    }

    private func parseStatistics(_ lines: [String]) -> Statistics? {
        var totalFiles: FileCount?
        var filesCreated: FileCount?
        var filesDeleted = 0
        var regularFilesTransferred = 0
        var totalFileSize: Int64 = 0
        var totalTransferredSize: Int64 = 0
        var literalData: Int64 = 0
        var matchedData: Int64 = 0
        var bytesSent: Int64 = 0
        var bytesReceived: Int64 = 0
        var speedup = 0.0

        for line in lines {
            if line.hasPrefix("Number of files:") {
                totalFiles = parseFileCount(line)
            } else if line.hasPrefix("Number of created files:") {
                filesCreated = parseFileCount(line)
            } else if line.hasPrefix("Number of deleted files:") {
                filesDeleted = extractNumber(from: line)
            } else if line.hasPrefix("Number of regular files transferred:") {
                regularFilesTransferred = extractNumber(from: line)
            } else if line.hasPrefix("Total file size:") {
                totalFileSize = extractBytes(from: line)
            } else if line.hasPrefix("Total transferred file size:") {
                totalTransferredSize = extractBytes(from: line)
            } else if line.hasPrefix("Literal data:") {
                literalData = extractBytes(from: line)
            } else if line.hasPrefix("Matched data:") {
                matchedData = extractBytes(from: line)
            } else if line.hasPrefix("Total bytes sent:") {
                bytesSent = Int64(extractNumber(from: line))
            } else if line.hasPrefix("Total bytes received:") {
                bytesReceived = Int64(extractNumber(from: line))
            } else if line.contains("speedup is") {
                speedup = extractSpeedup(from: line)
            }
        }

        guard let total = totalFiles else { return nil }

        return Statistics(
            totalFiles: total,
            filesCreated: filesCreated ?? FileCount(total: 0, regular: 0, directories: 0, links: 0),
            filesDeleted: filesDeleted,
            regularFilesTransferred: regularFilesTransferred,
            totalFileSize: totalFileSize,
            totalTransferredSize: totalTransferredSize,
            literalData: literalData,
            matchedData: matchedData,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            speedup: speedup
        )
    }

    private func parseFileCount(_ line: String) -> FileCount {
        // Number of files: 16,087 (reg: 14,321, dir: 1,721, link: 45)
        let pattern = #"(\d+(? : ,\d+)*)\s*\(reg:\s*(\d+(?: ,\d+)*),\s*dir:\s*(\d+(?:,\d+)*),\s*link:\s*(\d+(?:,\d+)*)\)"#

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let total = extractNumberFromMatch(line, match, at: 1)
            let regular = extractNumberFromMatch(line, match, at: 2)
            let directories = extractNumberFromMatch(line, match, at: 3)
            let links = extractNumberFromMatch(line, match, at: 4)

            return FileCount(total: total, regular: regular, directories: directories, links: links)
        }

        return FileCount(total: 0, regular: 0, directories: 0, links: 0)
    }

    private func extractNumber(from line: String) -> Int {
        let numbers = line.components(separatedBy: .whitespaces)
            .compactMap { $0.replacingOccurrences(of: ",", with: "") }
            .compactMap { Int($0) }
        return numbers.first ?? 0
    }

    private func extractBytes(from line: String) -> Int64 {
        let components = line.components(separatedBy: .whitespaces)
        for (index, component) in components.enumerated() {
            if let value = Int64(component.replacingOccurrences(of: ",", with: "")) {
                return value
            }
        }
        return 0
    }

    private func extractSpeedup(from line: String) -> Double {
        // speedup is 1,865.63
        let pattern = #"speedup is ([\d,]+\. ?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            let speedupString = String(line[range]).replacingOccurrences(of: ",", with: "")
            return Double(speedupString) ?? 0.0
        }
        return 0.0
    }

    private func extractNumberFromMatch(_ text: String, _ match: NSTextCheckingResult, at index: Int) -> Int {
        if let range = Range(match.range(at: index), in: text) {
            let numberString = String(text[range]).replacingOccurrences(of: ",", with: "")
            return Int(numberString) ?? 0
        }
        return 0
    }

    // MARK: - Utility Functions

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func efficiencyPercentage(statistics: Statistics) -> Double {
        guard statistics.totalFileSize > 0 else { return 0 }
        return (Double(statistics.totalTransferredSize) / Double(statistics.totalFileSize)) * 100.0
    }
}

// MARK: - Pretty Printing Extensions

extension ActorRsyncOutputAnalyzer.AnalysisResult: CustomStringConvertible {
    var description: String {
        var result = "=== Rsync Analysis ===\n"
        result += isDryRun ? "🔍 DRY RUN (no changes made)\n\n" : "✅ LIVE RUN\n\n"

        result += "📊 Statistics:\n"
        result += "  Total files: \(statistics.totalFiles.total)\n"
        result += "    - Regular:  \(statistics.totalFiles.regular)\n"
        result += "    - Directories: \(statistics.totalFiles.directories)\n"
        result += "    - Links: \(statistics.totalFiles.links)\n"
        result += "  Files created: \(statistics.filesCreated.total)\n"
        result += "  Files deleted: \(statistics.filesDeleted)\n"
        result += "  Files transferred: \(statistics.regularFilesTransferred)\n\n"

        result += "💾 Data Transfer:\n"
        result += "  Total size: \(ActorRsyncOutputAnalyzer.formatBytes(statistics.totalFileSize))\n"
        result += "  To transfer: \(ActorRsyncOutputAnalyzer.formatBytes(statistics.totalTransferredSize))\n"
        let efficiency = ActorRsyncOutputAnalyzer.efficiencyPercentage(statistics: statistics)
        result += "  Efficiency: \(String(format: "%.2f", efficiency))% needs transfer\n"
        result += "  Speedup: \(String(format: "%.2f", statistics.speedup))x\n\n"

        result += "🔄 Changes (\(itemizedChanges.count) items):\n"

        let symlinks = itemizedChanges.filter { $0.changeType == .symlink }
        let directories = itemizedChanges.filter { $0.changeType == .directory }
        let files = itemizedChanges.filter { $0.changeType == .file }

        if !symlinks.isEmpty {
            result += "  Symlinks: \(symlinks.count)\n"
        }
        if !directories.isEmpty {
            result += "  Directories: \(directories.count)\n"
        }
        if !files.isEmpty {
            result += "  Files: \(files.count)\n"
        }

        return result
    }
}
