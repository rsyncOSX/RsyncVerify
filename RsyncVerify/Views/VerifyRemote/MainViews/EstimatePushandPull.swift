//
//  EstimatePushandPull.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import SwiftUI

struct EstimatePushandPull: View {
    @Binding var verifypath: [Verify]
    /// Push data to remote, adjusted
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    /// Pull data from remote, adjusted
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    /// tagged or not
    @Binding var istagged: Bool

    let selectedconfig: SynchronizeConfiguration

    @State private var pullCompleted = false
    @State private var pushCompleted = false

    @State private var estimatePull: EstimatePull?
    @State private var estimatePush: EstimatePush?

    var body: some View {
        ZStack {
            if pullCompleted, pushCompleted {
                HStack {
                    PushDetailsSection(verifypath: $verifypath,
                                       selectedconfig: selectedconfig,
                                       pushremotedatanumbers: pushremotedatanumbers,
                                       istagged: istagged)

                    PullDetailsSection(verifypath: $verifypath,
                                       selectedconfig: selectedconfig,
                                       pullremotedatanumbers: pullremotedatanumbers,
                                       istagged: istagged)
                }
            } else {
                HStack {
                    ProgressView()

                    Text("Estimating \(selectedconfig.backupID) PUSH and PULL, please wait ...")
                        .font(.title2)
                }
            }
        }
        .task {
            startPushEstimation()
            startPullEstimation()
        }
    }

    func onCompletepull() {
        pullCompleted = true
    }

    func onCompletepush() {
        pushCompleted = true
    }

    private func startPullEstimation() {
        let estimate = EstimatePull(
            config: selectedconfig,
            onComplete: { [self] in
                handlePullCompletion()
            }
        )

        estimatePull = estimate
        estimate.pullRemote(config: selectedconfig)
    }

    private func handlePullCompletion() {
        Task { @MainActor in
            // Update the binding with results from EstimatePull
            pullremotedatanumbers = estimatePull?.pullremotedatanumbers
            // Mark completed
            onCompletepull()
            // Clean up
            estimatePull = nil
        }
    }

    private func startPushEstimation() {
        let estimate = EstimatePush(
            config: selectedconfig,
            onComplete: { [self] in
                handlePushCompletion()
            }
        )

        estimatePush = estimate
        estimate.pushRemote(config: selectedconfig)
    }

    private func handlePushCompletion() {
        Task { @MainActor in
            // Update the binding with results from EstimatePush
            pushremotedatanumbers = estimatePush?.pushremotedatanumbers
            // Mark completed
            onCompletepush()
            // Clean up
            estimatePush = nil
        }
    }
}
