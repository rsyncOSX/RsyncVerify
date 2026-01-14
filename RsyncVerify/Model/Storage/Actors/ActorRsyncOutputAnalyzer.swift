//
//  ActorRsyncOutputAnalyzer.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 11/01/2026.
//

import Foundation
import RsyncProcessStreaming

actor ActorRsyncOutputAnalyzer {
    // MARK: - Properties
    
    private var analysisCache: [Int: AnalysisResult] = [:]
    
    // MARK: - Public Interface
    
    func analyze(_ output: String) -> AnalysisResult? {
        return analyzeOutput(output)
    }
    
    func analyze(_ output: [RsyncOutputData]) -> AnalysisResult? {
        guard !output.isEmpty else { return nil }
        let stringData = output.map { $0.record }.joined(separator: "\n")
        return analyzeOutput(stringData)
    }
    
    func analyzeCached(_ output: String) -> AnalysisResult? {
        let hash = output.hashValue
        if let cached = analysisCache[hash] {
            return cached
        }
        
        let result = analyzeOutput(output)
        analysisCache[hash] = result
        return result
    }
    
    func clearCache() {
        analysisCache.removeAll()
    }
    
    // MARK: - Private Analysis
    
    private func analyzeOutput(_ output: String) -> AnalysisResult? {
        var itemizedChanges: [ItemizedChange] = []
        var statsLines: [String] = []
        var parsingStats = false
        var errors: [String] = []
        var warnings: [String] = []
        
        for rawLine in output.split(whereSeparator: { $0.isNewline }) {
            let line = String(rawLine)
            if line.hasPrefix("Number of files:") {
                parsingStats = true
            }
            
            if parsingStats {
                statsLines.append(line)
            } else if !line.isEmpty && !line.hasPrefix("sending incremental") {
                // Parse errors and warnings
                if line.lowercased().contains("error") {
                    errors.append(line)
                } else if line.lowercased().contains("warning") {
                    warnings.append(line)
                }
                
                // Parse itemized changes
                if let change = self.parseItemizedChange(line) {
                    itemizedChanges.append(change)
                }
            }
        }
        
        guard let statistics = parseStatistics(statsLines, errors: errors, warnings: warnings) else {
            return nil
        }
        
        let isDryRun = output.contains("(DRY RUN)")
        
        return AnalysisResult(
            itemizedChanges: itemizedChanges,
            statistics: statistics,
            isDryRun: isDryRun,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Parsing Functions
    
    private func parseItemizedChange(_ line: String) -> ItemizedChange? {
        // Handle empty or comment lines
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
        
        let components = line.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        guard components.count >= 2 else { return nil }
        
        let flagString = components[0]
        
        // Handle deletions
        if flagString == "*deleting" && components.count >= 2 {
            return ItemizedChange(
                changeType: .deletion,
                path: components[1...].joined(separator: " "),
                target: nil,
                flags: ChangeFlags(isDeletion: true)
            )
        }
        
        // Handle other itemized changes
        let changeType = parseChangeType(flagString)
        let flags = ChangeFlags(from: flagString)
        
        // Check for symlink target
        if let arrowIndex = components.firstIndex(of: "->") {
            let path = components[1..<arrowIndex].joined(separator: " ")
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
    
    private func parseStatistics(_ lines: [String], errors: [String], warnings: [String]) -> Statistics? {
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
            parseStatisticsLine(
                line,
                totalFiles: &totalFiles,
                filesCreated: &filesCreated,
                filesDeleted: &filesDeleted,
                regularFilesTransferred: &regularFilesTransferred,
                totalFileSize: &totalFileSize,
                totalTransferredSize: &totalTransferredSize,
                literalData: &literalData,
                matchedData: &matchedData,
                bytesSent: &bytesSent,
                bytesReceived: &bytesReceived,
                speedup: &speedup
            )
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
            speedup: speedup,
            errors: errors,
            warnings: warnings
        )
    }
    
    // swiftlint:disable:next function_parameter_count
    private func parseStatisticsLine(
        _ line: String,
        totalFiles: inout FileCount?,
        filesCreated: inout FileCount?,
        filesDeleted: inout Int,
        regularFilesTransferred: inout Int,
        totalFileSize: inout Int64,
        totalTransferredSize: inout Int64,
        literalData: inout Int64,
        matchedData: inout Int64,
        bytesSent: inout Int64,
        bytesReceived: inout Int64,
        speedup: inout Double
    ) {
        parseFileStatistics(
            line,
            totalFiles: &totalFiles,
            filesCreated: &filesCreated,
            filesDeleted: &filesDeleted,
            regularFilesTransferred: &regularFilesTransferred
        )
        parseByteStatistics(
            line,
            totalFileSize: &totalFileSize,
            totalTransferredSize: &totalTransferredSize,
            literalData: &literalData,
            matchedData: &matchedData,
            bytesSent: &bytesSent,
            bytesReceived: &bytesReceived,
            speedup: &speedup
        )
    }
    
    private func parseFileStatistics(
        _ line: String,
        totalFiles: inout FileCount?,
        filesCreated: inout FileCount?,
        filesDeleted: inout Int,
        regularFilesTransferred: inout Int
    ) {
        if line.hasPrefix("Number of files:") {
            totalFiles = parseFileCount(line)
        } else if line.hasPrefix("Number of created files:") {
            filesCreated = parseFileCount(line)
        } else if line.hasPrefix("Number of deleted files:") {
            filesDeleted = extractNumber(from: line)
        } else if line.hasPrefix("Number of regular files transferred:") {
            regularFilesTransferred = extractNumber(from: line)
        }
    }
    
    // swiftlint:disable:next function_parameter_count
    private func parseByteStatistics(
        _ line: String,
        totalFileSize: inout Int64,
        totalTransferredSize: inout Int64,
        literalData: inout Int64,
        matchedData: inout Int64,
        bytesSent: inout Int64,
        bytesReceived: inout Int64,
        speedup: inout Double
    ) {
        if line.hasPrefix("Total file size:") {
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
    
    private func parseFileCount(_ line: String) -> FileCount {
        // Number of files: 16,087 (reg: 14,321, dir: 1,721, link: 45)
        let pattern = #"(\d+(?:,\d+)*)\s*\(reg:\s*(\d+(?:,\d+)*),\s*dir:\s*(\d+(?:,\d+)*),\s*link:\s*(\d+(?:,\d+)*)\)"#
        
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
        let pattern = #"speedup is ([\d,]+\.?\d*)"#
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

// MARK: - Data Models (Add these if not already defined)

struct AnalysisResult {
    let itemizedChanges: [ItemizedChange]
    let statistics: Statistics
    let isDryRun: Bool
    let errors: [String]
    let warnings: [String]
}


enum ChangeType {
    case symlink
    case directory
    case file
    case device
    case special
    case deletion
    case unknown
}

struct ChangeFlags {
    let from: String
    let isDeletion: Bool
    
    init(from: String = "", isDeletion: Bool = false) {
        self.from = from
        self.isDeletion = isDeletion
    }
}

struct FileCount {
    let total: Int
    let regular: Int
    let directories: Int
    let links: Int
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
        
        let deletions = itemizedChanges.filter { $0.changeType == .deletion }
        let symlinks = itemizedChanges.filter { $0.changeType == .symlink }
        let directories = itemizedChanges.filter { $0.changeType == .directory }
        let files = itemizedChanges.filter { $0.changeType == .file }
        let others = itemizedChanges.filter { $0.changeType == .unknown || $0.changeType == .device || $0.changeType == .special }
        
        if !deletions.isEmpty {
            result += "  Deletions: \(deletions.count)\n"
        }
        if !symlinks.isEmpty {
            result += "  Symlinks: \(symlinks.count)\n"
        }
        if !directories.isEmpty {
            result += "  Directories: \(directories.count)\n"
        }
        if !files.isEmpty {
            result += "  Files: \(files.count)\n"
        }
        if !others.isEmpty {
            result += "  Other items: \(others.count)\n"
        }
        
        // Add errors and warnings
        if !statistics.errors.isEmpty {
            result += "\n❌ Errors (\(statistics.errors.count)):\n"
            for error in statistics.errors {
                result += "  - \(error)\n"
            }
        }
        
        if !statistics.warnings.isEmpty {
            result += "\n⚠️ Warnings (\(statistics.warnings.count)):\n"
            for warning in statistics.warnings {
                result += "  - \(warning)\n"
            }
        }
        
        return result
    }
    
    var detailedDescription: String {
        var result = description
        
        // Add detailed change list
        if !itemizedChanges.isEmpty {
            result += "\n📋 Detailed Changes:\n"
            for change in itemizedChanges.prefix(50) { // Limit to first 50
                result += "  \(change)\n"
            }
            if itemizedChanges.count > 50 {
                result += "  ... and \(itemizedChanges.count - 50) more\n"
            }
        }
        
        return result
    }
}

// MARK: - Error Handling (Optional)

enum RsyncAnalysisError: Error, LocalizedError {
    case emptyOutput
    case invalidFormat
    case missingStatistics
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyOutput:
            return "Empty rsync output"
        case .invalidFormat:
            return "Invalid rsync output format"
        case .missingStatistics:
            return "Missing statistics in rsync output"
        case .parsingFailed(let reason):
            return "Failed to parse rsync output: \(reason)"
        }
    }
}

// Optional extension for throwing version
extension ActorRsyncOutputAnalyzer {
    func analyzeThrowing(_ output: String) throws -> AnalysisResult {
        guard !output.isEmpty else {
            throw RsyncAnalysisError.emptyOutput
        }
        
        guard let result = analyzeOutput(output) else {
            throw RsyncAnalysisError.parsingFailed("Failed to parse rsync output")
        }
        
        return result
    }
}

