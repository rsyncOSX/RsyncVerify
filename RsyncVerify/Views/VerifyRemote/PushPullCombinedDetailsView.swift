//
//  PushPullCombinedDetailsView.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import OSLog
import SwiftUI

struct PushPullCombinedDetailsView: View {
    @Binding var verifypath: [Verify]

    let selectedconfig: SynchronizeConfiguration
    let pushremotedatanumbers: RemoteDataNumbers?
    let pullremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool

    var body: some View {
        HStack {
            PushDetailsSection(
                verifypath: $verifypath,
                selectedconfig: selectedconfig,
                pushremotedatanumbers: pushremotedatanumbers,
                istagged: istagged
            )

            PullDetailsSection(
                verifypath: $verifypath,
                selectedconfig: selectedconfig,
                pullremotedatanumbers: pullremotedatanumbers,
                istagged: istagged
            )
        }
    }
}
