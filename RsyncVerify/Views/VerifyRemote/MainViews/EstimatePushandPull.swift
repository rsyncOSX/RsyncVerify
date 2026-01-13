//
//  EstimatePushandPull.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import SwiftUI

struct EstimatePushandPull: View {
    @Binding var verifypath: [Verify]
    // Push data to remote, adjusted
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    @Binding var pushonly: Bool
    // Pull data from remote, adjusted
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    @Binding var pullonly: Bool

    let config: SynchronizeConfiguration
    let isadjusted: Bool

    @State private var pullCompleted = false

    var body: some View {
        HStack {
            PullView(
                verifypath: $verifypath,
                pullremotedatanumbers: $pullremotedatanumbers,
                config: config,
                isadjusted: isadjusted,
                onComplete: onComplete
            )

            if pullCompleted {
                PushView(
                    verifypath: $verifypath,
                    pushremotedatanumbers: $pushremotedatanumbers,
                    config: config,
                    isadjusted: isadjusted
                )
            }
        }
    }

    func onComplete() {
        pullCompleted = true
    }
}
