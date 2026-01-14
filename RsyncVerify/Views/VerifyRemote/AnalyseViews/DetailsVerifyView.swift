struct RsyncFileChange {
    let rawPrefix: String
    let path: String
    let updateType: Character
    let fileType: Character
    let attributes: [RsyncAttribute]

    init?(from record: String) {
        // Expect format like: ".d..t....... ./"
        // Position 0: update type (. * + - > h ? etc)
        // Position 1: file type (f d L D S)
        // Position 2-11: attribute codes
        guard record.count >= 13 else { return nil }
        
        let chars = Array(record)
        guard chars.count >= 12, chars[12] == " " else { return nil }

        let prefix = String(chars.prefix(12))
        updateType = chars[0]
        fileType = chars[1]

        var attrs: [RsyncAttribute] = []
        let attributePositions: [(index: Int, name: String, code: Character?)] = [
            (2, "checksum", "c"),
            (3, "size", "s"),
            (4, "time", "t"),
            (5, "permissions", "p"),
            (6, "owner", "o"),
            (7, "group", "g"),
            (8, "acl", "a"),
            (9, "xattr", "x")
        ]

        for position in attributePositions {
            guard position.index < chars.count else { continue }
            let char = chars[position.index]
            if let code = position.code, char == code {
                attrs.append(RsyncAttribute(name: position.name, code: char))
            }
        }

        rawPrefix = prefix
        path = String(chars.dropFirst(13)).trimmingCharacters(in: .whitespaces)
        attributes = attrs
    }

    var fileTypeLabel: String {
        switch fileType {
        case "f": return "file"
        case "d": return "dir"
        case "L": return "link"
        case "D": return "device"
        case "S": return "special"
        default: return String(fileType)
        }
    }

    var updateTypeLabel: (String, Color) {
        switch updateType {
        case ".": return ("NONE", .gray)
        case "*": return ("UPDATED", .orange)
        case "+": return ("CREATED", .green)
        case "-": return ("DELETED", .red)
        case ">": return ("RECEIVED", .blue)
        case "<": return ("SENT", .purple)
        case "h": return ("HARDLINK", .indigo)
        case "?": return ("ERROR", .red)
        default: return (String(updateType), .primary)
        }
    }
}

struct RsyncAttribute: Identifiable {
    let id = UUID()
    let name: String
    let code: Character
}

// MARK: - Fallback ItemizedChange Parser

struct ItemizedChange {
    let path: String
    let updateType: Character
    let fileType: Character
    let changedAttributes: [String]
    
    init?(from record: String) {
        let components = record.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        guard components.count >= 2 else { return nil }
        
        let flagString = components[0]
        let flagChars = Array(flagString)
        
        guard flagChars.count >= 2 else { return nil }
        
        self.updateType = flagChars[0]
        self.fileType = flagChars[1]
        self.path = components.dropFirst().joined(separator: " ")
        
        // Parse changed attributes from flag string positions 2+
        var attributes: [String] = []
        if flagChars.count > 2 {
            let attributeMapping: [Character: String] = [
                "c": "checksum",
                "s": "size",
                "t": "time",
                "p": "permissions",
                "o": "owner",
                "g": "group",
                "a": "acl",
                "x": "xattr"
            ]
            
            for char in flagChars.dropFirst(2) {
                if let attributeName = attributeMapping[char] {
                    attributes.append(attributeName)
                }
            }
        }
        
        self.changedAttributes = attributes
    }
    
    var updateDescription: (String, Color) {
        switch updateType {
        case ".": return ("UNCHANGED", .gray)
        case "*": return ("UPDATED", .orange)
        case "+": return ("CREATED", .green)
        case "-": return ("DELETED", .red)
        case ">": return ("TRANSFERRED", .blue)
        case "<": return ("SENT", .purple)
        case "h": return ("HARDLINK", .indigo)
        case "?": return ("ERROR", .red)
        default: return (String(updateType), .primary)
        }
    }
    
    var fileTypeDescription: String {
        switch fileType {
        case "f": return "file"
        case "d": return "dir"
        case "L": return "link"
        case "D": return "device"
        case "S": return "special"
        default: return String(fileType)
        }
    }
}

// MARK: - SwiftUI View

import SwiftUI

struct DetailsVerifyView: View {
    let remotedatanumbers: RemoteDataNumbers
    let istagged: Bool
    
    var body: some View {
        if let records = remotedatanumbers.outputfromrsync {
            if istagged {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        parseRecordRow(data.record)
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
        }
    }
    
    @ViewBuilder
    private func parseRecordRow(_ record: String) -> some View {
        if record.contains("*deleting") {
            HStack(spacing: 4) {
                Text("DELETE")
                    .foregroundColor(.white)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(4)
                Text(record)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } else if let rsyncChange = RsyncFileChange(from: record) {
            // Enhanced rsync output with detailed attributes
            HStack(spacing: 6) {
                // Update type tag
                let (updateText, updateColor) = rsyncChange.updateTypeLabel
                Text(updateText)
                    .foregroundColor(.white)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(updateColor)
                    .cornerRadius(4)

                // File type tag
                Text(rsyncChange.fileTypeLabel)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)

                // Changed attributes
                if !rsyncChange.attributes.isEmpty {
                    ForEach(rsyncChange.attributes) { attr in
                        Text(attr.name)
                            .foregroundColor(.orange)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                // Path
                Text(rsyncChange.path)
                    .lineLimit(1)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } else if let change = ItemizedChange(from: record) {
            // Fallback to simplified parser
            HStack(spacing: 6) {
                // Update type tag
                let (updateText, updateColor) = change.updateDescription
                Text(updateText)
                    .foregroundColor(.white)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(updateColor)
                    .cornerRadius(4)

                // File type tag
                Text(change.fileTypeDescription)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)

                // Changed attributes
                if !change.changedAttributes.isEmpty {
                    ForEach(change.changedAttributes, id: \.self) { attr in
                        Text(attr)
                            .foregroundColor(.orange)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                // Path
                Text(change.path)
                    .lineLimit(1)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } else {
            Text(record)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}
