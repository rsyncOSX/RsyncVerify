//
//  PullView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/01/2026.
//

import OSLog
import RsyncProcessStreaming
import SwiftUI

struct PullView: View {
    @Binding var verifypath: [Verify]
    @Binding var pushpullcommand: PushPullCommand
    // Pull data from remote, adjusted
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    // Push data to remote, adjusted
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    // Pullonly
    @Binding var pullonly: Bool
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

            Text("Estimating \(config.backupID) PULL, please wait ...")
                .font(.title2)
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            pullRemote(config: config)
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
    func pullRemote(config: SynchronizeConfiguration) {
        let arguments = ArgumentsPullRemote(config: config).argumentspullremotewithparameters(dryRun: true,
                                                                                              forDisplay: false,
                                                                                              keepdelete: true)

        streamingHandlers = CreateStreamingHandlers().createHandlers(
            fileHandler: { _ in },
            processTermination: { output, hiddenID in
                pullProcessTermination(stringoutputfromrsync: output, hiddenID: hiddenID)
            }
        )

        guard SharedReference.shared.norsync == false else { return }
        guard config.task != SharedReference.shared.halted else { return }
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

    func pullProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) {
        Task { @MainActor in
            guard isaborted == false else { return }

            // Process output
            let processedOutput: [String]? = if let output = stringoutputfromrsync, output.count > 17 {
                PrepareOutputFromRsync().prepareOutputFromRsync(output)
            } else {
                stringoutputfromrsync
            }

            // Create data numbers
            pullremotedatanumbers = RemoteDataNumbers(
                stringoutputfromrsync: processedOutput,
                config: config
            )
            if isadjusted == false {
                // Create output for view
                let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
                pullremotedatanumbers?.outputfromrsync = out
            } else {
                pullremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: stringoutputfromrsync,
                                                          config: config)
            }
            // Release current streaming before next task
            if let count = pullremotedatanumbers?.outputfromrsync?.count, count > 0 {
                pullremotedatanumbers?.maxpushpull = Double(count)
            }
            activeStreamingProcess = nil
            streamingHandlers = nil
            verifypath.removeAll()
        }
    }

    func abort() {
        InterruptProcess()
    }
}
