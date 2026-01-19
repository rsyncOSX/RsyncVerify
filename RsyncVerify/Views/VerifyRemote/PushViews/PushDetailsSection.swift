//
//  PushDetailsSection.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/01/2026.
//

import OSLog
import SwiftUI

struct PushDetailsSection: View {
    @Binding var verifypath: [Verify]

    let selectedconfig: SynchronizeConfiguration
    let pushremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ConditionalGlassButton(
                    systemImage: "arrow.right",
                    helpText: "Push to remote"
                ) {
                    verifypath.append(Verify(task: .executenpushview(configID: selectedconfig.id)))
                }

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
            .padding()

            if let pushremotedatanumbers {
                DetailsVerifyView(remotedatanumbers: pushremotedatanumbers,
                                  istagged: istagged)
                    .padding(10)
            }
        }
    }
}
