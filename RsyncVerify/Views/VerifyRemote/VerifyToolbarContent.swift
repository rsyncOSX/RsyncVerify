//
//  VerifyToolbarContent.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import SwiftUI

struct VerifyToolbarContent: ToolbarContent {
    let pushandpullestimated: Bool
    let disabledpushpull: Bool
    let selectedconfig: SynchronizeConfiguration?
    let selectedtaskishalted: Bool
    @Binding var showinspector: Bool
    @Binding var verifypath: [Verify]
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    @Binding var selecteduuids: Set<SynchronizeConfiguration.ID>
    @Binding var selectedconfigBinding: SynchronizeConfiguration?
    
    var body: some ToolbarContent {
        ToolbarItem {
            if pushandpullestimated == false {
                ConditionalGlassButton(
                    systemImage: "arrow.up",
                    helpText: "Verify selected"
                ) {
                    guard let selectedconfig else { return }
                    guard selectedtaskishalted == false else { return }
                    guard SharedReference.shared.process == nil else { return }
                    showinspector = false
                    verifypath.append(Verify(task: .pushview(configID: selectedconfig.id)))
                }
                .disabled(disabledpushpull)
            }
        }

        ToolbarItem {
            Spacer()
        }

        if pushandpullestimated == true {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "figure.run",
                    helpText: "Excute"
                ) {
                    guard let selectedconfig else { return }
                    verifypath.append(Verify(task: .executenpushpullview(configID: selectedconfig.id)))
                }
                .disabled(disabledpushpull)
            }
        }

        ToolbarItem {
            Spacer()
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "trash.fill",
                helpText: "Reset"
            ) {
                pullremotedatanumbers = nil
                pushremotedatanumbers = nil
                selecteduuids.removeAll()
                selectedconfigBinding = nil
                verifypath.removeAll()
            }
        }

        ToolbarItem {
            Spacer()
        }
    }
}
