//
//  DetailsVerifyView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 11/01/2026.
//

import SwiftUI
import RsyncAnalyse

// MARK: - SwiftUI View Components

struct DetailsVerifyView: View {
    let remotedatanumbers: RemoteDataNumbers
    let istagged: Bool

    var body: some View {
        if let records = remotedatanumbers.outputfromrsync {
            if istagged {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        RsyncOutputRowView(record: data.record)
                    }
                }
            } else {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        Text(data.record)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
        } else {
            Text("No rsync output available")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Row View Component

struct RsyncOutputRowView: View {
    let record: String

    var body: some View {
        if let parsed = RsyncOutputRecord(from: record) {
            ParsedRsyncRow(parsed: parsed)
        } else {
            // Unparseable output - show as plain text
            Text(record)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Parsed Row Component

struct ParsedRsyncRow: View {
    let parsed: RsyncOutputRecord

    var body: some View {
        HStack(spacing: 6) {
            // Update type tag
            UpdateTypeTag(updateTypeLabel: parsed.updateTypeLabel)

            // File type tag
            FileTypeTag(fileTypeLabel: parsed.fileTypeLabel)

            // Changed attributes
            if !parsed.attributes.isEmpty {
                ForEach(parsed.attributes) { attr in
                    AttributeBadge(name: attr.name)
                }
            }

            // Path
            Text(parsed.path)
                .lineLimit(1)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Reusable Tag Components

struct UpdateTypeTag: View {
    let updateTypeLabel: (text: String, color: Color)

    var body: some View {
        Text(updateTypeLabel.text)
            .foregroundColor(.white)
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(updateTypeLabel.color)
            .cornerRadius(4)
            .accessibilityLabel("Update type: \(updateTypeLabel.text)")
    }
}

struct FileTypeTag: View {
    let fileTypeLabel: String

    var body: some View {
        Text(fileTypeLabel)
            .foregroundColor(.secondary)
            .font(.caption)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(3)
            .accessibilityLabel("File type: \(fileTypeLabel)")
    }
}

struct AttributeBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .foregroundColor(.orange)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(3)
            .accessibilityLabel("Changed attribute: \(name)")
    }
}
