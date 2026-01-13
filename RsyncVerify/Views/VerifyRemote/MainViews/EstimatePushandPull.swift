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
    // tagged or not
    @Binding var istagged: Bool

    let config: SynchronizeConfiguration
    let isadjusted: Bool

    @State private var pullCompleted = false
    @State private var pushCompleted = false

    @State private var estimatePull: EstimatePull?
    @State private var estimatePush: EstimatePush?

    var body: some View {
        ZStack {
            if pullCompleted, pushCompleted {
                HStack {
                    PushDetailsSection(pushremotedatanumbers: pushremotedatanumbers,
                                       istagged: istagged,
                                       verifypath: $verifypath)

                    PullDetailsSection(pullremotedatanumbers: pullremotedatanumbers,
                                       istagged: istagged,
                                       verifypath: $verifypath)
                }

            } else {
                HStack {
                    ProgressView()

                    Text("Estimating \(config.backupID) PUSH and PULL, please wait ...")
                        .font(.title2)
                }
            }
        }
        .task {
            startPushEstimation()
            startPullEstimation()
        }
    }

    func onCompletepull() { pullCompleted = true }

    func onCompletepush() { pushCompleted = true }

    private func startPullEstimation() {
        let estimate = EstimatePull(
            config: config,
            isadjusted: isadjusted,
            onComplete: { [self] in
                handlePullCompletion()
            }
        )

        estimatePull = estimate
        estimate.pullRemote(config: config)
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
            config: config,
            isadjusted: isadjusted,
            onComplete: { [self] in
                handlePushCompletion()
            }
        )

        estimatePush = estimate
        estimate.pushRemote(config: config)
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
