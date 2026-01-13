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
    @Binding var verifypath: [Verify]
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    @Binding var selecteduuids: Set<SynchronizeConfiguration.ID>
    @Binding var selectedconfigBinding: SynchronizeConfiguration?

    var body: some ToolbarContent {
        
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
