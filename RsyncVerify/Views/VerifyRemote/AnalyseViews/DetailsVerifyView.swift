//
//  DetailsVerifyView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 20/11/2024.
//

// Rsync itemized change format documentation:
// YXcstpoguax  path/to/file
// Where Y is one of:
//   '.' = no change
//   '*' = updated
//   '+' = created
//   '-' = deleted
//   '>' = transferred
//   'h' = hard link
//   '.' = unchanged
//   '?' = message

// X is one of:
//   'f' = file
//   'd' = directory
//   'L' = symlink
//   'D' = device
//   'S' = special

// Remaining positions (cstpoguax):
//   c = checksum changed
//   s = size changed
//   t = time changed
//   p = permissions changed
//   o = owner changed
//   g = group changed
//   u = unused
//   a = ACL changed
//   x = extended attributes changed
// swiftlint:disable identifier_name

import SwiftUI

struct ItemizedChange {
    let updateType: Character // Y position
    let fileType: Character // X position
    let checksumChanged: Bool // c position
    let sizeChanged: Bool // s position
    let timeChanged: Bool // t position
    let permissionsChanged: Bool // p position
    let ownerChanged: Bool // o position
    let groupChanged: Bool // g position
    let aclChanged: Bool // a position
    let xattrChanged: Bool // x position
    let path: String

    init?(from record: String) {
        // Check if record starts with itemized format (11 chars + space)
        guard record.count >= 12, record.dropFirst(11).first == " " else {
            return nil
        }

        let prefix = String(record.prefix(11))
        updateType = prefix[prefix.startIndex]
        fileType = prefix[prefix.index(prefix.startIndex, offsetBy: 1)]

        let c = prefix[prefix.index(prefix.startIndex, offsetBy: 2)]
        let s = prefix[prefix.index(prefix.startIndex, offsetBy: 3)]
        let t = prefix[prefix.index(prefix.startIndex, offsetBy: 4)]
        let p = prefix[prefix.index(prefix.startIndex, offsetBy: 5)]
        let o = prefix[prefix.index(prefix.startIndex, offsetBy: 6)]
        let g = prefix[prefix.index(prefix.startIndex, offsetBy: 7)]
        // position 8 (u) is unused
        let a = prefix[prefix.index(prefix.startIndex, offsetBy: 9)]
        let x = prefix[prefix.index(prefix.startIndex, offsetBy: 10)]

        checksumChanged = (c == "c")
        sizeChanged = (s == "s")
        timeChanged = (t == "t")
        permissionsChanged = (p == "p")
        ownerChanged = (o == "o")
        groupChanged = (g == "g")
        aclChanged = (a == "a")
        xattrChanged = (x == "x")

        path = String(record.dropFirst(12))
    }

    var updateDescription: (String, Color) {
        switch updateType {
        case "<": ("PUSH", .blue)
        case ">": ("PULL", .green)
        case "c": ("CHANGE", .orange)
        case "*": ("MESSAGE", .purple)
        case ".": ("NO CHANGE", .gray)
        case "+": ("NEW", .green)
        case " ": ("IDENTICAL", .gray)
        default: (String(updateType), .primary)
        }
    }

    var fileTypeDescription: String {
        switch fileType {
        case "f": "file"
        case "d": "dir"
        case "L": "link"
        case "D": "device"
        case "S": "special"
        default: String(fileType)
        }
    }

    var changedAttributes: [String] {
        var attrs: [String] = []
        if checksumChanged { attrs.append("content") }
        if sizeChanged { attrs.append("size") }
        if timeChanged { attrs.append("time") }
        if permissionsChanged { attrs.append("perms") }
        if ownerChanged { attrs.append("owner") }
        if groupChanged { attrs.append("group") }
        if aclChanged { attrs.append("acl") }
        if xattrChanged { attrs.append("xattr") }
        return attrs
    }
}

// Parse detailed rsync output with file attribute codes
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
        guard record.count >= 13, record[record.index(record.startIndex, offsetBy: 12)] == " " else {
            return nil
        }

        struct AttributePosition {
            let index: Int
            let name: String
            let code: Character?
        }

        let prefix = String(record.prefix(12))
        updateType = prefix[prefix.startIndex]
        fileType = prefix[prefix.index(prefix.startIndex, offsetBy: 1)]

        var attrs: [RsyncAttribute] = []
        let attributePositions: [AttributePosition] = [
            AttributePosition(index: 2, name: "checksum", code: "c"),
            AttributePosition(index: 3, name: "size", code: "s"),
            AttributePosition(index: 4, name: "time", code: "t"),
            AttributePosition(index: 5, name: "permissions", code: "p"),
            AttributePosition(index: 6, name: "owner", code: "o"),
            AttributePosition(index: 7, name: "group", code: "g"),
            AttributePosition(index: 8, name: "acl", code: "a"),
            AttributePosition(index: 9, name: "xattr", code: "x")
        ]

        for position in attributePositions {
            let char = prefix[prefix.index(prefix.startIndex, offsetBy: position.index)]
            if let code = position.code, char == code {
                attrs.append(RsyncAttribute(name: position.name, code: char))
            }
        }

        rawPrefix = prefix
        path = String(record.dropFirst(13)).trimmingCharacters(in: .whitespaces)
        attributes = attrs
    }

    var fileTypeLabel: String {
        switch fileType {
        case "f": "file"
        case "d": "dir"
        case "L": "link"
        case "D": "device"
        case "S": "special"
        default: String(fileType)
        }
    }

    var updateTypeLabel: (String, Color) {
        switch updateType {
        case ".": ("NONE", .gray)
        case "*": ("UPDATED", .orange)
        case "+": ("CREATED", .green)
        case "-": ("DELETED", .red)
        case ">": ("RECEIVED", .blue)
        case "<": ("SENT", .purple)
        case "h": ("HARDLINK", .indigo)
        case "?": ("ERROR", .red)
        default: (String(updateType), .primary)
        }
    }
}

struct RsyncAttribute {
    let name: String
    let code: Character
}

struct DetailsVerifyView: View {
    let remotedatanumbers: RemoteDataNumbers
    let istagged: Bool

    var body: some View {
        if let records = remotedatanumbers.outputfromrsync {
            if istagged {
                Table(records) {
                    TableColumn("Output from rsync" + ": \(records.count) rows") { data in
                        if data.record.contains("*deleting") {
                            HStack(spacing: 4) {
                                Text("DELETE").foregroundColor(.white)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(4)
                                Text(data.record)
                            }
                        } else if let rsyncChange = RsyncFileChange(from: data.record) {
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
                                    ForEach(rsyncChange.attributes, id: \.name) { attr in
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
                            }
                        } else if let change = ItemizedChange(from: data.record) {
                            // Fallback to original parser
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
                            }
                        } else {
                            Text(data.record)
                        }
                    }
                }
            } else {
                Table(records) {
                    TableColumn("Output from rsync" + ": \(records.count) rows") { data in
                        Text(data.record)
                    }
                }
            }
        }
    }
}

// swiftlint:enable identifier_name
