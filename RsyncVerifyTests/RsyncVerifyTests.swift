//
//  RsyncVerifyTests.swift
//  RsyncVerifyTests
//
//  Created by Thomas Evensen on 11/01/2026.
//

@testable import RsyncVerify
import Testing
import Foundation

struct RsyncAnalyzerTests {
    private let analyzer = ActorRsyncOutputAnalyzer()

    // MARK: - Basic Parsing Tests

    @Test("Basic rsync output parsing")
    func basicParsing() async {
        let output = """
        .f..t....... file1.txt
        .d..t....... folder/
        .L..t....... link.txt -> /path/to/target
        *deleting oldfile.txt
        Number of files: 10 (reg: 8, dir: 1, link: 1)
        Number of created files: 2 (reg: 2, dir: 0, link: 0)
        Number of deleted files: 1
        Number of regular files transferred: 3
        Total file size: 1,024 bytes
        Total transferred file size: 512 bytes
        Literal data: 256 bytes
        Matched data: 256 bytes
        Total bytes sent: 1024
        Total bytes received: 512
        speedup is 2.00
        """

        let result = await analyzer.analyze(output)
        #expect(result != nil)
        #expect(result?.itemizedChanges.count == 4)
        #expect(result?.statistics.totalFiles.total == 10)
        #expect(result?.statistics.filesDeleted == 1)
        #expect(result?.statistics.speedup == 2.0)
    }

    @Test("Dry run detection")
    func dryRunDetection() async {
        let output = """
        .f..t....... file.txt
        (DRY RUN)
        Number of files: 1 (reg: 1, dir: 0, link: 0)
        """

        let result = await analyzer.analyze(output)
        #expect(result?.isDryRun == true)
    }

    @Test("Empty output handling")
    func emptyOutput() async {
        let result = await analyzer.analyze("")
        #expect(result == nil)
    }

    @Test("Statistics parsing with commas")
    func statisticsWithCommas() async {
        let output = """
        Number of files: 16,087 (reg: 14,321, dir: 1,721, link: 45)
        Number of created files: 102 (reg: 100, dir: 2, link: 0)
        Total file size: 1,024,576 bytes
        Total transferred file size: 512,288 bytes
        speedup is 1,865.63
        """

        let result = await analyzer.analyze(output)
        #expect(result != nil)
        #expect(result?.statistics.totalFiles.total == 16087)
        #expect(result?.statistics.totalFiles.regular == 14321)
        #expect(result?.statistics.totalFiles.directories == 1721)
        #expect(result?.statistics.totalFiles.links == 45)
        #expect(result?.statistics.filesCreated.total == 102)
        #expect(result?.statistics.totalFileSize == 1_024_576)
        #expect(result?.statistics.speedup == 1865.63)
    }

    // MARK: - Itemized Changes Tests

    @Test("Symlink parsing with target")
    func symlinkParsing() async {
        let output = """
        .L..t....... symlink.txt -> /absolute/path/to/target
        .L..t....... relative/link -> ../target
        Number of files: 2 (reg: 0, dir: 0, link: 2)
        """

        let result = await analyzer.analyze(output)
        #expect(result?.itemizedChanges.count == 2)

        let symlinks = result?.itemizedChanges.filter { $0.changeType == .symlink }
        #expect(symlinks?.count == 2)
        #expect(symlinks?.first?.target == "/absolute/path/to/target")
        #expect(symlinks?.last?.target == "../target")
    }

    @Test("Deletion parsing")
    func deletionParsing() async {
        let output = """
        *deleting file1.txt
        *deleting folder/file2.txt
        Number of files: 0 (reg: 0, dir: 0, link: 0)
        Number of deleted files: 2
        """

        let result = await analyzer.analyze(output)
        #expect(result?.itemizedChanges.count == 2)

        let deletions = result?.itemizedChanges.filter { $0.changeType == .deletion }
        #expect(deletions?.count == 2)
        #expect(deletions?.first?.path == "file1.txt")
        #expect(deletions?.last?.path == "folder/file2.txt")
    }

    @Test("File type detection")
    func fileTypeDetection() async {
        let output = """
        .f..t....... regular.txt
        .d..t....... directory/
        .L..t....... link
        .D..t....... device
        .S..t....... special
        Number of files: 5 (reg: 1, dir: 1, link: 1, dev: 1, special: 1)
        """

        let result = await analyzer.analyze(output)
        #expect(result?.itemizedChanges.count == 5)

        let changes = result?.itemizedChanges
        #expect(changes?[0].changeType == .file)
        #expect(changes?[1].changeType == .directory)
        #expect(changes?[2].changeType == .symlink)
        #expect(changes?[3].changeType == .device)
        #expect(changes?[4].changeType == .special)
    }

    // MARK: - Error and Warning Tests

    @Test("Error and warning detection")
    func errorWarningDetection() async {
        let output = """
        .f..t....... file.txt
        WARNING: something happened
        ERROR: something went wrong
        ERROR: another error
        Number of files: 1 (reg: 1, dir: 0, link: 0)
        """

        let result = await analyzer.analyze(output)
        #expect(result?.statistics.errors.count == 2)
        #expect(result?.statistics.warnings.count == 1)
        #expect(result?.errors.count == 2)
        #expect(result?.warnings.count == 1)
    }

    // MARK: - Cache Tests

    @Test("Cache functionality")
    func cacheFunctionality() async {
        let output = """
        .f..t....... cached.txt
        Number of files: 1 (reg: 1, dir: 0, link: 0)
        """

        // First call should compute
        let result1 = await analyzer.analyzeCached(output)
        #expect(result1 != nil)

        // Second call should use cache
        let result2 = await analyzer.analyzeCached(output)
        #expect(result2 != nil)

        // Clear cache
        await analyzer.clearCache()

        // Should compute again
        let result3 = await analyzer.analyzeCached(output)
        #expect(result3 != nil)
    }

    // MARK: - Edge Cases

    @Test("Missing statistics")
    func missingStatistics() async {
        let output = """
        .f..t....... file.txt
        .d..t....... folder/
        """

        let result = await analyzer.analyze(output)
        #expect(result == nil)
    }

    @Test("Incomplete statistics line")
    func incompleteStatistics() async {
        let output = """
        .f..t....... file.txt
        Number of files: 1
        """

        let result = await analyzer.analyze(output)
        // Should still parse but with zero values for missing parts
        #expect(result != nil)
        #expect(result?.statistics.totalFiles.total == 1)
        #expect(result?.statistics.totalFiles.regular == 0)
    }

    @Test("Large speedup value")
    func largeSpeedup() async {
        let output = """
        Number of files: 1 (reg: 1, dir: 0, link: 0)
        speedup is 12,345.67
        """

        let result = await analyzer.analyze(output)
        #expect(result?.statistics.speedup == 12345.67)
    }

    @Test("Array input parsing")
    func arrayInputParsing() async {
        let data = [
            RsyncOutputData(record: ".f..t....... file1.txt"),
            RsyncOutputData(record: ".d..t....... folder/"),
            RsyncOutputData(record: "Number of files: 2 (reg: 1, dir: 1, link: 0)"),
            RsyncOutputData(record: "Total file size: 1024 bytes")
        ]

        let result = await analyzer.analyze(data)
        #expect(result != nil)
        #expect(result?.itemizedChanges.count == 2)
        #expect(result?.statistics.totalFiles.total == 2)
    }

    @Test("Empty array input")
    func emptyArrayInput() async {
        let result = await analyzer.analyze([])
        #expect(result == nil)
    }

    // MARK: - Utility Function Tests

    @Test("Format bytes utility")
    func formatBytesUtility() {
        let bytes: Int64 = 1_048_576 // 1 MB
        let formatted = ActorRsyncOutputAnalyzer.formatBytes(bytes)
        #expect(formatted.contains("MB"))
    }

    @Test("Efficiency percentage calculation")
    func efficiencyPercentage() {
        let stats = ActorRsyncOutputAnalyzer.Statistics(
            totalFiles: .zero,
            filesCreated: .zero,
            filesDeleted: 0,
            regularFilesTransferred: 0,
            totalFileSize: 1000,
            totalTransferredSize: 500,
            literalData: 0,
            matchedData: 0,
            bytesSent: 0,
            bytesReceived: 0,
            speedup: 1.0,
            errors: [],
            warnings: []
        )

        let efficiency = ActorRsyncOutputAnalyzer.efficiencyPercentage(statistics: stats)
        #expect(efficiency == 50.0)
    }

    @Test("Zero efficiency for zero total size")
    func zeroEfficiency() {
        let stats = ActorRsyncOutputAnalyzer.Statistics(
            totalFiles: .zero,
            filesCreated: .zero,
            filesDeleted: 0,
            regularFilesTransferred: 0,
            totalFileSize: 0,
            totalTransferredSize: 1000,
            literalData: 0,
            matchedData: 0,
            bytesSent: 0,
            bytesReceived: 0,
            speedup: 1.0,
            errors: [],
            warnings: []
        )

        let efficiency = ActorRsyncOutputAnalyzer.efficiencyPercentage(statistics: stats)
        #expect(efficiency == 0.0)
    }
}

// MARK: - Integration Test

struct IntegrationTests {
    @Test("End-to-end integration test")
    func endToEndIntegration() async {
        let analyzer = ActorRsyncOutputAnalyzer()

        let complexOutput = """
        .f..t....... unchanged.txt
        >f.stp...... updated.txt
        +f......... newfile.txt
        -f......... deleted.txt
        .L..t....... link.txt -> target.txt
        *deleting manually_deleted.txt
        WARNING: Some warning message
        ERROR: Failed to set permissions on some file

        Number of files: 100 (reg: 80, dir: 15, link: 5)
        Number of created files: 10 (reg: 8, dir: 2, link: 0)
        Number of deleted files: 15
        Number of regular files transferred: 25
        Total file size: 10,485,760 bytes
        Total transferred file size: 2,621,440 bytes
        Literal data: 1,048,576 bytes
        Matched data: 1,572,864 bytes
        Total bytes sent: 2,621,440
        Total bytes received: 1,048,576
        speedup is 4.00
        """

        let result = await analyzer.analyze(complexOutput)
        #expect(result != nil)

        // Verify counts
        #expect(result?.itemizedChanges.count == 6)
        #expect(result?.statistics.totalFiles.total == 100)
        #expect(result?.statistics.filesCreated.total == 10)
        #expect(result?.statistics.filesDeleted == 15)
        #expect(result?.statistics.regularFilesTransferred == 25)

        // Verify calculations
        #expect(result?.statistics.totalFilesChanged == 25) // 10 created + 15 deleted
        let efficiency = result?.statistics.efficiencyPercentage ?? 0
        #expect(efficiency > 0 && efficiency < 100)

        // Verify error/warning detection
        #expect(result?.statistics.errors.count == 1)
        #expect(result?.statistics.warnings.count == 1)

        // Verify change types
        guard let validResult = result else {
            Issue.record("Result should not be nil")
            return
        }
        let changesByType = await analyzer.changesByType(for: validResult)
        #expect(changesByType[.file] ?? 0 > 0)
        #expect(changesByType[.symlink] ?? 0 > 0)
        #expect(changesByType[.deletion] ?? 0 > 0)

        // Verify summary generation
        let summary = await analyzer.summary(for: validResult)
        #expect(summary.contains("RSYNC ANALYSIS SUMMARY"))
        #expect(summary.contains("Total items: 6"))

        // Verify speedup
        #expect(result?.statistics.speedup == 4.0)

        // Verify data sizes
        #expect(result?.statistics.totalFileSize == 10_485_760)
        #expect(result?.statistics.totalTransferredSize == 2_621_440)
        #expect(result?.statistics.literalData == 1_048_576)
        #expect(result?.statistics.matchedData == 1_572_864)
    }
}

// MARK: - Performance Tests

struct PerformanceTests {
    private let analyzer = ActorRsyncOutputAnalyzer()

    @Test("Performance with 10k lines", .timeLimit(.minutes(1)))
    func performance10kLines() async {
        let largeOutput = generateLargeOutput(lines: 10000)
        let result = await analyzer.analyze(largeOutput)
        #expect(result != nil)
        #expect(result?.itemizedChanges.count ?? 0 > 0)
    }

    @Test("Performance with 50k lines", .timeLimit(.minutes(1)))
    func performance50kLines() async {
        let largeOutput = generateLargeOutput(lines: 50000)
        let result = await analyzer.analyze(largeOutput)
        #expect(result != nil)
    }

    @Test("Performance with 100k lines", .timeLimit(.minutes(1)))
    func performance100kLines() async {
        let largeOutput = generateLargeOutput(lines: 100_000)
        let result = await analyzer.analyze(largeOutput)
        #expect(result != nil)
    }

    @Test("Cache performance improvement")
    func cachePerformance() async {
        let mediumOutput = generateLargeOutput(lines: 5000)

        // First parse (no cache)
        let start1 = Date()
        _ = await analyzer.analyzeCached(mediumOutput)
        let duration1 = Date().timeIntervalSince(start1)

        // Second parse (with cache)
        let start2 = Date()
        _ = await analyzer.analyzeCached(mediumOutput)
        let duration2 = Date().timeIntervalSince(start2)

        // Cached version should be significantly faster
        #expect(duration2 < duration1 * 0.1) // At least 10x faster

        await analyzer.clearCache()
    }

    @Test("Concurrent analysis performance", .timeLimit(.minutes(1)))
    func concurrentAnalysis() async {
        let output = generateLargeOutput(lines: 1000)

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 50 {
                group.addTask {
                    let result = await analyzer.analyze(output)
                    return result != nil
                }
            }

            var successCount = 0
            for await success in group where success {
                successCount += 1
            }

            #expect(successCount == 50)
        }
    }

    @Test("Memory efficiency with repeated parsing")
    func memoryEfficiency() async {
        // Parse and discard many outputs to test memory management
        for _ in 0 ..< 100 {
            let output = generateLargeOutput(lines: 1000)
            let result = await analyzer.analyze(output)
            #expect(result != nil)
        }
        // If we get here without memory issues, test passes
    }

    // MARK: - Helper Methods

    private func generateLargeOutput(lines: Int) -> String {
        var output = ""

        // Generate various types of changes
        let changeTypes = [
            ".f..t.......",
            ">f.stp......",
            ".d..t.......",
            ".L..t.......",
            "*deleting"
        ]

        for lineIndex in 0 ..< lines {
            if lineIndex % 1000 == 0 {
                // Add some variety
                let changeType = changeTypes.randomElement() ?? ".f..t......."
                output += changeType + " file_\(lineIndex).txt\n"
            } else {
                output += ".f..t....... file_\(lineIndex).txt\n"
            }
        }

        // Add statistics section
        output += """

        Number of files: \(lines) (reg: \(lines - 100), dir: 80, link: 20)
        Number of created files: \(lines / 10) (reg: \(lines / 10), dir: 0, link: 0)
        Number of deleted files: \(lines / 20)
        Number of regular files transferred: \(lines / 5)
        Total file size: \(lines * 1024) bytes
        Total transferred file size: \(lines * 512) bytes
        Literal data: \(lines * 256) bytes
        Matched data: \(lines * 256) bytes
        Total bytes sent: \(lines * 512)
        Total bytes received: \(lines * 256)
        speedup is 2.00
        """

        return output
    }
}
