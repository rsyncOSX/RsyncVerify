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
    // Pull data from remote, adjusted
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    @Binding var pullonly: Bool
    @Binding var pushonly: Bool

    let config: SynchronizeConfiguration
    let isadjusted: Bool

    @State private var pullCompleted = false
    @State private var pushCompleted = false

    var body: some View {
        ZStack {
            PullView(
                verifypath: $verifypath,
                pullremotedatanumbers: $pullremotedatanumbers,
                pullonly: $pullonly,
                config: config,
                isadjusted: isadjusted,
                onComplete: onCompletepull
            )

            if pullCompleted {
                PushView(
                    verifypath: $verifypath,
                    pushremotedatanumbers: $pushremotedatanumbers,
                    pushonly: $pushonly,
                    config: config,
                    isadjusted: isadjusted,
                    onComplete: onCompletepush
                )
            }

            HStack {
                if pullCompleted, pushCompleted {
                    analyseView(for: pushremotedatanumbers)
                    analyseView(for: pullremotedatanumbers)
                }
            }
        }
    }

    @ViewBuilder
    private func analyseView(for remotedatanumbers: RemoteDataNumbers?) -> some View {
        if let output = remotedatanumbers?.outputfromrsync {
            AsyncAnalyseView(output: output)
        }
    }

    func onCompletepull() {
        pullCompleted = true
    }

    func onCompletepush() {
        pushCompleted = true
    }
}
