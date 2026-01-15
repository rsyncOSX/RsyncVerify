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

