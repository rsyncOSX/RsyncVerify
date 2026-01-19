//
//  PullDetailsSection.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/01/2026.
//

import OSLog
import SwiftUI

struct PullDetailsSection: View {
    @Binding var verifypath: [Verify]

    let selectedconfig: SynchronizeConfiguration
    let pullremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ConditionalGlassButton(
                    systemImage: "arrow.left",
                    helpText: "Pull from remote"
                ) {
                    verifypath.append(Verify(task: .executenpullview(configID: selectedconfig.id)))
                }

                ConditionalGlassButton(
                    systemImage: "square.and.arrow.down.fill",
                    helpText: "Save Pull data to file"
                ) {
                    Task {
                        if let output = pullremotedatanumbers?.outputfromrsync {
                            Logger.process.debugMessageOnly("Execute: LOGGING details to logfile")
                            _ = await ActorLogToFile().logOutput("PULL output", output)
                        }
                    }
                }

                ConditionalGlassButton(
                    systemImage: "questionmark.text.page.fill",
                    helpText: "Analyze output from Pull"
                ) {
                    verifypath.append(Verify(task: .analyseviewpull))
                }
            }
            .padding()

            if let pullremotedatanumbers {
                DetailsVerifyView(remotedatanumbers: pullremotedatanumbers,
                                  istagged: istagged)
                    .padding(10)
            }
        }
    }
}
