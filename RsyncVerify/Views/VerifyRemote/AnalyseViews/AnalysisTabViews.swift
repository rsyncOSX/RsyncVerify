//
//  AnalysisTabViews.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import SwiftUI

// MARK: - Overview Tab

struct AnalysisOverviewView: View {
    let statistics: ActorRsyncOutputAnalyzer.Statistics
    let itemizedChanges: [ActorRsyncOutputAnalyzer.ItemizedChange]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                quickStatsSection
                changesSummarySection
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
                StatCard(title: "Total Files", value: "\(statistics.totalFiles.total)", icon: "doc.on.doc", color: .blue)
                StatCard(
                    title: "Files Transferred",
                    value: "\(statistics.regularFilesTransferred)",
                    icon: "arrow.left.arrow.right",
                    color: .purple
                )
                StatCard(title: "Files Created", value: "\(statistics.filesCreated.total)", icon: "plus.circle", color: .green)
                StatCard(title: "Files Deleted", value: "\(statistics.filesDeleted)", icon: "trash", color: .red)
            }
        }
    }

    private var changesSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Changes Summary")

            VStack(spacing: 8) {
                ChangeTypeRow(icon: "📄", label: "Files", count: itemizedChanges.filter { $0.changeType == .file }.count, color: .blue)
                ChangeTypeRow(
                    icon: "📁",
                    label: "Directories",
                    count: itemizedChanges.filter { $0.changeType == .directory }.count,
                    color: .orange
                )
                ChangeTypeRow(
                    icon: "🔗",
                    label: "Symlinks",
                    count: itemizedChanges.filter { $0.changeType == .symlink }.count,
                    color: .purple
                )

                let otherCount = itemizedChanges.filter {
                    $0.changeType == .device || $0.changeType == .special || $0.changeType == .unknown
                }.count

                if otherCount > 0 {
                    ChangeTypeRow(icon: "⚙️", label: "Other", count: otherCount, color: .gray)
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
                    Text(ActorRsyncOutputAnalyzer.formatBytes(statistics.totalFileSize))
                        .fontWeight(.medium)
                }

                HStack {
                    Text("To Transfer:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ActorRsyncOutputAnalyzer.formatBytes(statistics.totalTransferredSize))
                        .fontWeight(.medium)
                }

                Divider()

                HStack {
                    Text("Efficiency:")
                        .foregroundColor(.secondary)
                    Spacer()
                    let efficiency = ActorRsyncOutputAnalyzer.efficiencyPercentage(statistics: statistics)
                    Text(String(format: "%.2f%%", efficiency))
                        .fontWeight(.bold)
                        .foregroundColor(efficiency < 10 ? .green : efficiency < 50 ? .orange : .red)
                }

                HStack {
                    Text("Speedup:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2fx", statistics.speedup))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Changes Tab

struct AnalysisChangesView: View {
    let changes: [ActorRsyncOutputAnalyzer.ItemizedChange]
    @Binding var searchText: String
    @Binding var selectedChangeTypes: Set<ActorRsyncOutputAnalyzer.ChangeType>

    var body: some View {
        VStack(spacing: 0) {
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
                            Button {
                                selectedChangeTypes.removeAll()
                            } label: {
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

            List(filteredChanges, id: \.path) { change in
                ChangeItemRow(change: change)
            }
        }
    }

    private var filteredChanges: [ActorRsyncOutputAnalyzer.ItemizedChange] {
        var filtered = changes

        if !searchText.isEmpty {
            filtered = filtered.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
        }

        if !selectedChangeTypes.isEmpty {
            filtered = filtered.filter { selectedChangeTypes.contains($0.changeType) }
        }

        return filtered
    }

    private func toggleFilter(_ type: ActorRsyncOutputAnalyzer.ChangeType) {
        if selectedChangeTypes.contains(type) {
            selectedChangeTypes.remove(type)
        } else {
            selectedChangeTypes.insert(type)
        }
    }
}

// MARK: - Statistics Tab

struct AnalysisStatisticsView: View {
    let statistics: ActorRsyncOutputAnalyzer.Statistics

    var body: some View {
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
                StatRow(label: "Total Files", value: "\(statistics.totalFiles.total)")
                StatRow(label: "  Regular Files", value: "\(statistics.totalFiles.regular)", indent: true)
                StatRow(label: "  Directories", value: "\(statistics.totalFiles.directories)", indent: true)
                StatRow(label: "  Symbolic Links", value: "\(statistics.totalFiles.links)", indent: true)

                Divider()

                StatRow(label: "Files Created", value: "\(statistics.filesCreated.total)")
                StatRow(label: "  Regular Files", value: "\(statistics.filesCreated.regular)", indent: true)
                StatRow(label: "  Directories", value: "\(statistics.filesCreated.directories)", indent: true)
                StatRow(label: "  Symbolic Links", value: "\(statistics.filesCreated.links)", indent: true)

                Divider()

                StatRow(label: "Files Deleted", value: "\(statistics.filesDeleted)")
                StatRow(label: "Files Transferred", value: "\(statistics.regularFilesTransferred)")
            }
        }
    }

    private var transferStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "arrow.up.arrow.down", title: "Transfer Statistics")

            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "Total File Size", value: ActorRsyncOutputAnalyzer.formatBytes(statistics.totalFileSize))
                StatRow(label: "Total Transferred", value: ActorRsyncOutputAnalyzer.formatBytes(statistics.totalTransferredSize))

                Divider()

                StatRow(label: "Bytes Sent", value: ActorRsyncOutputAnalyzer.formatBytes(statistics.bytesSent))
                StatRow(label: "Bytes Received", value: ActorRsyncOutputAnalyzer.formatBytes(statistics.bytesReceived))

                Divider()

                StatRow(label: "Speedup Factor", value: String(format: "%.2fx", statistics.speedup))
            }
        }
    }

    private var dataBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "chart.pie", title: "Data Breakdown")

            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "Literal Data", value: ActorRsyncOutputAnalyzer.formatBytes(statistics.literalData))
                StatRow(label: "Matched Data", value: ActorRsyncOutputAnalyzer.formatBytes(statistics.matchedData))

                let total = statistics.literalData + statistics.matchedData
                if total > 0 {
                    let literalPercent = (Double(statistics.literalData) / Double(total)) * 100
                    let matchedPercent = (Double(statistics.matchedData) / Double(total)) * 100

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
}
