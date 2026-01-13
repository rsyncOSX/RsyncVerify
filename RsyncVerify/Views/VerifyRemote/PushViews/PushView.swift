//
//  PushView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/01/2026.
//

import Observation
import OSLog
import RsyncProcessStreaming
import SwiftUI

struct PushView: View {
    @Binding var verifypath: [Verify]
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    @Binding var pushonly: Bool

    @State private var isaborted: Bool = false
    @State private var estimatePush: EstimatePush?

    let config: SynchronizeConfiguration
    let isadjusted: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack {
            ProgressView()

            Text("Estimating \(config.backupID) PUSH, please wait ...")
                .font(.title2)
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            startPushEstimation()
        }
        .toolbar(content: {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "stop.fill",
                    helpText: "Abort"
                ) {
                    isaborted = true
                    abort()
                }
            }
        })
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
            guard !isaborted else { return }

            // Update the binding with results from EstimatePush
            pushremotedatanumbers = estimatePush?.pushremotedatanumbers

            // Clear verification path
            verifypath.removeAll()

            // Mark completed
            onComplete()

            if pushonly {
                verifypath.append(Verify(task: .pushviewonly))
            }

            // Clean up
            estimatePush = nil
        }
    }

    func abort() {
        InterruptProcess()
        estimatePush?.activeStreamingProcess = nil
        estimatePush?.streamingHandlers = nil
        estimatePush = nil
    }
}
