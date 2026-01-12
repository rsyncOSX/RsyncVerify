//
//  RsyncAnalysisView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/01/2026.
//

import SwiftUI

struct RsyncAnalysisView: View {
    let analysisResult: ActorRsyncOutputAnalyzer.AnalysisResult
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedChangeTypes: Set<ActorRsyncOutputAnalyzer.ChangeType> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with run type
            runTypeHeader
            
            // Tab selection
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Changes").tag(1)
                Text("Statistics").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                overviewView
                    .tag(0)
                
                changesView
                    .tag(1)
                
                statisticsView
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
    }
    
    // MARK: - Header
    
    private var runTypeHeader: some View {
        HStack {
            Image(systemName: analysisResult.isDryRun ? "eye" : "checkmark.circle.fill")
                .foregroundColor(analysisResult.isDryRun ? .orange : .green)
            Text(analysisResult.isDryRun ? "DRY RUN (no changes made)" : "LIVE RUN")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(analysisResult.isDryRun ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
    }
    
    // MARK: - Overview Tab
    
    private var overviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Quick stats
                quickStatsSection
                
                // Changes summary
                changesSummarySection
                
                // Transfer efficiency
                transferEfficiencySection
            }
            .padding()
        }
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "chart.bar.fill", title: "Quick Stats")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Files",
                    value: "\(analysisResult.statistics.totalFiles.total)",
                    icon: "doc.on.doc",
                    color: .blue
                )
                
                StatCard(
                    title: "Files Transferred",
                    value: "\(analysisResult.statistics.regularFilesTransferred)",
                    icon: "arrow.left.arrow.right",
                    color: .purple
                )
                
                StatCard(
                    title: "Files Created",
                    value: "\(analysisResult.statistics.filesCreated.total)",
                    icon: "plus.circle",
                    color: .green
                )
                
                StatCard(
                    title: "Files Deleted",
                    value: "\(analysisResult.statistics.filesDeleted)",
                    icon: "trash",
                    color: .red
                )
            }
        }
    }
    
    private var changesSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Changes Summary")
            
            VStack(spacing: 8) {
                ChangeTypeRow(
                    icon: "📄",
                    label: "Files",
                    count: analysisResult.itemizedChanges.filter { $0.changeType == .file }.count,
                    color: .blue
                )
                
                ChangeTypeRow(
                    icon: "📁",
                    label: "Directories",
                    count: analysisResult.itemizedChanges.filter { $0.changeType == .directory }.count,
                    color: .orange
                )
                
                ChangeTypeRow(
                    icon: "🔗",
                    label: "Symlinks",
                    count: analysisResult.itemizedChanges.filter { $0.changeType == .symlink }.count,
                    color: .purple
                )
                
                let otherCount = analysisResult.itemizedChanges.filter {
                    $0.changeType == .device || $0.changeType == .special || $0.changeType == .unknown
                }.count
                
                if otherCount > 0 {
                    ChangeTypeRow(
                        icon: "⚙️",
                        label: "Other",
                        count: otherCount,
                        color: .gray
                    )
                }
            }
        }
    }
    
    private var transferEfficiencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "gauge", title: "Transfer Efficiency")
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Size:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.totalFileSize))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("To Transfer:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.totalTransferredSize))
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text("Efficiency:")
                        .foregroundColor(.secondary)
                    Spacer()
                    let efficiency = ActorRsyncOutputAnalyzer.efficiencyPercentage(statistics: analysisResult.statistics)
                    Text(String(format: "%.2f%%", efficiency))
                        .fontWeight(.bold)
                        .foregroundColor(efficiencyColor(efficiency))
                }
                
                HStack {
                    Text("Speedup:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2fx", analysisResult.statistics.speedup))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Changes Tab
    
    private var changesView: some View {
        VStack(spacing: 0) {
            // Search and filter
            VStack(spacing: 12) {
                TextField("Search changes...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            icon: "📄",
                            label: "Files",
                            isSelected: selectedChangeTypes.contains(.file),
                            action: { toggleFilter(.file) }
                        )
                        
                        FilterChip(
                            icon: "📁",
                            label: "Directories",
                            isSelected: selectedChangeTypes.contains(.directory),
                            action: { toggleFilter(.directory) }
                        )
                        
                        FilterChip(
                            icon: "🔗",
                            label: "Symlinks",
                            isSelected: selectedChangeTypes.contains(.symlink),
                            action: { toggleFilter(.symlink) }
                        )
                        
                        if selectedChangeTypes.count > 0 {
                            Button(action: { selectedChangeTypes.removeAll() }) {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            // Changes list
            List(filteredChanges, id: \.path) { change in
                ChangeItemRow(change: change)
            }
        }
    }
    
    private var filteredChanges: [ActorRsyncOutputAnalyzer.ItemizedChange] {
        var changes = analysisResult.itemizedChanges
        
        // Filter by search text
        if !searchText.isEmpty {
            changes = changes.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Filter by selected change types
        if !selectedChangeTypes.isEmpty {
            changes = changes.filter { selectedChangeTypes.contains($0.changeType) }
        }
        
        return changes
    }
    
    private func toggleFilter(_ type: ActorRsyncOutputAnalyzer.ChangeType) {
        if selectedChangeTypes.contains(type) {
            selectedChangeTypes.remove(type)
        } else {
            selectedChangeTypes.insert(type)
        }
    }
    
    // MARK: - Statistics Tab
    
    private var statisticsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                fileStatisticsSection
                transferStatisticsSection
                dataBreakdownSection
            }
            .padding()
        }
    }
    
    private var fileStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "doc.text", title: "File Statistics")
            
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "Total Files", value: "\(analysisResult.statistics.totalFiles.total)")
                StatRow(label: "  Regular Files", value: "\(analysisResult.statistics.totalFiles.regular)", indent: true)
                StatRow(label: "  Directories", value: "\(analysisResult.statistics.totalFiles.directories)", indent: true)
                StatRow(label: "  Symbolic Links", value: "\(analysisResult.statistics.totalFiles.links)", indent: true)
                
                Divider()
                
                StatRow(label: "Files Created", value: "\(analysisResult.statistics.filesCreated.total)")
                StatRow(label: "  Regular Files", value: "\(analysisResult.statistics.filesCreated.regular)", indent: true)
                StatRow(label: "  Directories", value: "\(analysisResult.statistics.filesCreated.directories)", indent: true)
                StatRow(label: "  Symbolic Links", value: "\(analysisResult.statistics.filesCreated.links)", indent: true)
                
                Divider()
                
                StatRow(label: "Files Deleted", value: "\(analysisResult.statistics.filesDeleted)")
                StatRow(label: "Files Transferred", value: "\(analysisResult.statistics.regularFilesTransferred)")
            }
        }
    }
    
    private var transferStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "arrow.up.arrow.down", title: "Transfer Statistics")
            
            VStack(alignment: .leading, spacing: 8) {
                StatRow(
                    label: "Total File Size",
                    value: ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.totalFileSize)
                )
                StatRow(
                    label: "Total Transferred",
                    value: ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.totalTransferredSize)
                )
                
                Divider()
                
                StatRow(
                    label: "Bytes Sent",
                    value: ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.bytesSent)
                )
                StatRow(
                    label: "Bytes Received",
                    value: ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.bytesReceived)
                )
                
                Divider()
                
                StatRow(
                    label: "Speedup Factor",
                    value: String(format: "%.2fx", analysisResult.statistics.speedup)
                )
            }
        }
    }
    
    private var dataBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "chart.pie", title: "Data Breakdown")
            
            VStack(alignment: .leading, spacing: 8) {
                StatRow(
                    label: "Literal Data",
                    value: ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.literalData)
                )
                StatRow(
                    label: "Matched Data",
                    value: ActorRsyncOutputAnalyzer.formatBytes(analysisResult.statistics.matchedData)
                )
                
                let total = analysisResult.statistics.literalData + analysisResult.statistics.matchedData
                if total > 0 {
                    let literalPercent = (Double(analysisResult.statistics.literalData) / Double(total)) * 100
                    let matchedPercent = (Double(analysisResult.statistics.matchedData) / Double(total)) * 100
                    
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * CGFloat(literalPercent / 100))
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * CGFloat(matchedPercent / 100))
                            }
                        }
                        .frame(height: 20)
                        .cornerRadius(4)
                        
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("Literal: \(String(format: "%.1f%%", literalPercent))")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Matched: \(String(format: "%.1f%%", matchedPercent))")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func efficiencyColor(_ efficiency: Double) -> Color {
        if efficiency < 10 { return .green }
        if efficiency < 50 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
        }
        .padding(.bottom, 4)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ChangeTypeRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(icon)
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var indent: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(indent ? .secondary : .primary)
                .padding(.leading, indent ? 16 : 0)
            Spacer()
            Text(value)
                .fontWeight(indent ? .regular : .medium)
        }
        .padding(.vertical, 2)
    }
}

struct FilterChip: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct ChangeItemRow: View {
    let change: ActorRsyncOutputAnalyzer.ItemizedChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Change type icon
                Text(changeTypeIcon)
                    .font(.title3)
                
                // Path
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.path)
                        .font(.body)
                        .lineLimit(2)
                    
                    // Target for symlinks
                    if let target = change.target {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(target)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Flags
            if hasFlags {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if change.flags.checksum {
                            FlagBadge(label: "checksum", color: .blue)
                        }
                        if change.flags.size {
                            FlagBadge(label: "size", color: .orange)
                        }
                        if change.flags.timestamp {
                            FlagBadge(label: "time", color: .purple)
                        }
                        if change.flags.permissions {
                            FlagBadge(label: "perms", color: .green)
                        }
                        if change.flags.owner {
                            FlagBadge(label: "owner", color: .red)
                        }
                        if change.flags.group {
                            FlagBadge(label: "group", color: .pink)
                        }
                        if change.flags.acl {
                            FlagBadge(label: "acl", color: .indigo)
                        }
                        if change.flags.xattr {
                            FlagBadge(label: "xattr", color: .teal)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var changeTypeIcon: String {
        switch change.changeType {
        case .file: return "📄"
        case .directory: return "📁"
        case .symlink: return "🔗"
        case .device: return "💿"
        case .special: return "⚙️"
        case .unknown: return "❓"
        }
    }
    
    private var hasFlags: Bool {
        change.flags.checksum || change.flags.size || change.flags.timestamp ||
        change.flags.permissions || change.flags.owner || change.flags.group ||
        change.flags.acl || change.flags.xattr
    }
}

struct FlagBadge: View {
    let label: String
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    RsyncAnalysisView(
        analysisResult: ActorRsyncOutputAnalyzer.AnalysisResult(
            itemizedChanges: [
                ActorRsyncOutputAnalyzer.ItemizedChange(
                    changeType: .file,
                    path: "/Users/test/Documents/file1.txt",
                    target: nil,
                    flags: ActorRsyncOutputAnalyzer.ChangeFlags(from: ".f.st......")
                ),
                ActorRsyncOutputAnalyzer.ItemizedChange(
                    changeType: .directory,
                    path: "/Users/test/Documents/newfolder",
                    target: nil,
                    flags: ActorRsyncOutputAnalyzer.ChangeFlags(from: ".d..........")
                ),
                ActorRsyncOutputAnalyzer.ItemizedChange(
                    changeType: .symlink,
                    path: "/Users/test/link",
                    target: "/Users/test/target",
                    flags: ActorRsyncOutputAnalyzer.ChangeFlags(from: ".L.....p...")
                )
            ],
            statistics: ActorRsyncOutputAnalyzer.Statistics(
                totalFiles: ActorRsyncOutputAnalyzer.FileCount(
                    total: 16087,
                    regular: 14321,
                    directories: 1721,
                    links: 45
                ),
                filesCreated: ActorRsyncOutputAnalyzer.FileCount(
                    total: 10,
                    regular: 8,
                    directories: 2,
                    links: 0
                ),
                filesDeleted: 5,
                regularFilesTransferred: 25,
                totalFileSize: 5_000_000_000,
                totalTransferredSize: 250_000_000,
                literalData: 200_000_000,
                matchedData: 50_000_000,
                bytesSent: 300_000,
                bytesReceived: 150_000,
                speedup: 1865.63
            ),
            isDryRun: true
        )
    )
}
