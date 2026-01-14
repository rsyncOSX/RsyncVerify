//
//  RsyncVerifyTests.swift
//  RsyncVerifyTests
//
//  Created by Thomas Evensen on 11/01/2026.
//

@testable import RsyncVerify
import Testing

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

// MARK: - RsyncFileChange Tests

struct RsyncFileChangeTests {
    @Test("Valid RsyncFileChange parsing")
    func validParsing() {
        let record = ".f..t....... file.txt"
        let change = RsyncFileChange(from: record)

        #expect(change != nil)
        #expect(change?.updateType == ".")
        #expect(change?.fileType == "f")
        #expect(change?.path == "file.txt")
        #expect(change?.attributes.count == 1)
        #expect(change?.attributes.first?.name == "time")
        #expect(change?.fileTypeLabel == "file")
    }

    @Test("Invalid RsyncFileChange parsing")
    func invalidParsing() {
        // Too short
        #expect(RsyncFileChange(from: "short") == nil)

        // Missing space at position 12
        #expect(RsyncFileChange(from: "123456789012file.txt") == nil)

        // Empty string
        #expect(RsyncFileChange(from: "") == nil)
    }

    @Test("Multiple attributes parsing")
    func multipleAttributes() {
        let record = ">f.stp...... newfile.txt"
        let change = RsyncFileChange(from: record)

        #expect(change != nil)
        #expect(change?.updateType == ">")
        #expect(change?.fileType == "f")
        #expect(change?.attributes.count == 3)

        let attributeNames = change?.attributes.map(\.name) ?? []
        #expect(attributeNames.contains("size"))
        #expect(attributeNames.contains("time"))
        #expect(attributeNames.contains("permissions"))
    }

    @Test("Update type labels")
    func updateTypeLabels() {
        let testCases: [(Character, String)] = [
            (".", "NONE"),
            ("*", "UPDATED"),
            ("+", "CREATED"),
            ("-", "DELETED"),
            (">", "RECEIVED"),
            ("<", "SENT"),
            ("h", "HARDLINK"),
            ("?", "ERROR"),
            ("X", "X") // unknown
        ]

        for (updateType, expectedText) in testCases {
            let record = "\(updateType)f..t....... file.txt"
            if let change = RsyncFileChange(from: record) {
                let (text, _) = change.updateTypeLabel
                #expect(text == expectedText)
            }
        }
    }
}

// MARK: - ItemizedChange Tests

struct ItemizedChangeTests {
    @Test("Valid ItemizedChange parsing")
    func validParsing() {
        let record = ".f..t....... file.txt"
        let change = ItemizedChange(from: record)

        #expect(change != nil)
        #expect(change?.updateType == ".")
        #expect(change?.fileType == "f")
        #expect(change?.path == "file.txt")
        #expect(change?.changedAttributes.contains("time") ?? false)
        #expect(change?.fileTypeDescription == "file")
    }

    @Test("ItemizedChange with multiple attributes")
    func multipleAttributes() {
        let record = ">f.stp...... newfile.txt"
        let change = ItemizedChange(from: record)

        #expect(change != nil)
        #expect(change?.changedAttributes.count == 3)
        #expect(change?.changedAttributes.contains("size") ?? false)
        #expect(change?.changedAttributes.contains("time") ?? false)
        #expect(change?.changedAttributes.contains("permissions") ?? false)
    }

    @Test("Invalid ItemizedChange parsing")
    func invalidParsing() {
        // Too few components
        #expect(ItemizedChange(from: "flagsonly") == nil)

        // Too short flag string
        #expect(ItemizedChange(from: "f file.txt") == nil)

        // Empty string
        #expect(ItemizedChange(from: "") == nil)
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
        let changesByType = await analyzer.changesByType(for: result!)
        #expect(changesByType[.file] ?? 0 > 0)
        #expect(changesByType[.symlink] ?? 0 > 0)
        #expect(changesByType[.deletion] ?? 0 > 0)

        // Verify summary generation
        let summary = await analyzer.summary(for: result!)
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
