//
//  PullDetailsSection.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/01/2026.
//

import SwiftUI
import OSLog

struct PullDetailsSection: View {
    let pullremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool
    @Binding var verifypath: [Verify]
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                HStack {
                    
                    Text(Image(systemName: "arrow.left")) + Text("Pull ")
                        
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
