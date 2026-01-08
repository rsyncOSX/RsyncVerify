//
//  PushView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/01/2026.
//

import OSLog
import RsyncProcessStreaming
import SwiftUI

struct PushView: View {
    @Binding var pushorpull: ObservableVerifyRemotePushPull
    @Binding var verifypath: [Verify]
    @Binding var pushpullcommand: PushPullCommand
    // Push data to remote, adjusted
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    // If aborted
    @State private var isaborted: Bool = false

    // Streaming strong references
    @State private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    @State private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?

    let config: SynchronizeConfiguration
    let isadjusted: Bool
    let reduceestimatedcount: Int = 15

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
            pushRemote(config: config)
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

    // For check remote, pull remote data
    func pushRemote(config: SynchronizeConfiguration) {
        let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(dryRun: true,
                                                                                                         forDisplay: false,
                                                                                                         keepdelete: true)
        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { _ in },
            processTermination: { output, hiddenID in
                pushProcessTermination(stringoutputfromrsync: output, hiddenID: hiddenID)
            },
            cleanup: { activeStreamingProcess = nil; streamingHandlers = nil }
        )

        guard let arguments else { return }
        guard let streamingHandlers else { return }

        let process = RsyncProcessStreaming.RsyncProcess(
            arguments: arguments,
            hiddenID: config.hiddenID,
            handlers: streamingHandlers,
            useFileHandler: false
        )
        do {
            try process.executeProcess()
            activeStreamingProcess = process
        } catch let err {
            let error = err
            SharedReference.shared.errorobject?.alert(error: error)
        }
    }

    // This is a normal synchronize task, dry-run = true
    func pushProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) {
        Task { @MainActor in
            guard isaborted == false else { return }

            // Process output
            let processedOutput: [String]? = if let output = stringoutputfromrsync, output.count > 17 {
                PrepareOutputFromRsync().prepareOutputFromRsync(output)
            } else {
                stringoutputfromrsync
            }

            // Create data numbers
            pushremotedatanumbers = RemoteDataNumbers(
                stringoutputfromrsync: processedOutput,
                config: config
            )

            // Create output for view
            let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
            pushremotedatanumbers?.outputfromrsync = out

            // Cleanup after all async work completes
            activeStreamingProcess = nil
            streamingHandlers = nil
            verifypath.removeAll()
            verifypath.append(Verify(task: .pullview(configID: config.id)))
        }
    }

    func abort() {
        InterruptProcess()
    }
}
