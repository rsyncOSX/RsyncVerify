//
//  PushPullCommandView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/12/2024.
//

import SwiftUI

struct PushPullCommandView: View {
    @Binding var dryrun: Bool
    @Binding var keepdelete: Bool

    let config: SynchronizeConfiguration
    let push: Bool

    var body: some View {
        VStack(alignment: .leading) {
            showcommand
        }
        .padding()
    }

    var showcommand: some View {
        Text(commandstring ?? "")
            .textSelection(.enabled)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue, lineWidth: 1)
            )
    }

    var commandstring: String? {
        PushPullCommandtoDisplay(push: push,
                                 config: config,
                                 dryRun: dryrun,
                                 keepdelete: keepdelete).command
    }
}
