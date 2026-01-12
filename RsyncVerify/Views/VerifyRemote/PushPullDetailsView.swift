//
//  PushPullDetailsView.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import OSLog
import SwiftUI

struct PushPullDetailsView: View {
    let pushremotedatanumbers: RemoteDataNumbers?
    let pullremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool
    @Binding var verifypath: [Verify]
    
    var body: some View {
        HStack {
            PushDetailsSection(
                pushremotedatanumbers: pushremotedatanumbers,
                istagged: istagged,
                verifypath: $verifypath
            )
            
            PullDetailsSection(
                pullremotedatanumbers: pullremotedatanumbers,
                istagged: istagged,
                verifypath: $verifypath
            )
        }
    }
}

struct PushDetailsSection: View {
    let pushremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool
    @Binding var verifypath: [Verify]
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Push")
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

struct PullDetailsSection: View {
    let pullremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool
    @Binding var verifypath: [Verify]
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Pull")
                    .font(.title2)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(10)

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

            if let pullremotedatanumbers {
                DetailsVerifyView(remotedatanumbers: pullremotedatanumbers,
                                  istagged: istagged)
                    .padding(10)
            }
        }
    }
}
