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

import SwiftUI

struct DetailsVerifyView: View {
    let remotedatanumbers: RemoteDataNumbers
    let istagged: Bool

    var body: some View {
        if let records = remotedatanumbers.outputfromrsync {
            if istagged {
                Table(records) {
                    TableColumn("Output from rsync" + ": \(records.count) rows") { data in
                        if data.record.contains("*deleting") {
                            HStack {
                                Text("delete").foregroundColor(.red)
                                Text(data.record)
                            }

                        } else if data.record.contains("<") {
                            HStack {
                                Text("push").foregroundColor(.blue)
                                Text(data.record)
                            }

                        } else if data.record.contains(">") {
                            HStack {
                                Text("pull").foregroundColor(.green)
                                Text(data.record)
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
