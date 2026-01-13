//
//  PushDetailsSection.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/01/2026.
//

import OSLog
import SwiftUI

struct PushDetailsSection: View {
    let pushremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool
    @Binding var verifypath: [Verify]

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                HStack {
                    Text("Push ") + Text(Image(systemName: "arrow.right"))
                }
                .font(.title2)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(10)

                ConditionalGlassButton(
                    systemImage: "square.and.arrow.down.fill",
                    helpText: "Save Push data to file"
                ) {
                    Task {
                        if let output = pushremotedatanumbers?.outputfromrsync {
                            Logger.process.debugMessageOnly("Execute: LOGGING details to logfile")
                            _ = await ActorLogToFile().logOutput("PUSH output", output)
                        }
                    }
                }

                ConditionalGlassButton(
                    systemImage: "questionmark.text.page.fill",
                    helpText: "Analyze output from Push"
                ) {
                    verifypath.append(Verify(task: .analyseviewpush))
                }
            }

            if let pushremotedatanumbers {
                DetailsVerifyView(remotedatanumbers: pushremotedatanumbers,
                                  istagged: istagged)
                    .padding(10)
            }
        }
    }
}
