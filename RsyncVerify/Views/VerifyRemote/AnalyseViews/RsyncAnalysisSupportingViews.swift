//
//  RsyncAnalysisSupportingViews.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import SwiftUI
import RsyncAnalyse

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
    let change: ActorRsyncOutputAnalyser.ItemizedChange

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
        case .file: "📄"
        case .directory: "📁"
        case .symlink: "🔗"
        case .device: "💿"
        case .special: "⚙️"
        case .unknown: "❓"
        case .deletion: "🗑️"
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
