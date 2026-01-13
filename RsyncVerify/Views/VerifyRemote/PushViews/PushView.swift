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
    @Binding var verifypath: [Verify]
    // Push data to remote, adjusted
    @Binding var pushremotedatanumbers: RemoteDataNumbers?
    @Binding var pushonly: Bool
    // If aborted
    @State private var isaborted: Bool = false

    // Streaming strong references
    @State private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    @State private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?

    let config: SynchronizeConfiguration
    let isadjusted: Bool
    let reduceestimatedcount: Int = 15
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
            if isadjusted == false {
                // Create output for view
                let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
                pushremotedatanumbers?.outputfromrsync = out
            } else {
                pushremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: stringoutputfromrsync,
                                                          config: config)
            }
            if let count = pushremotedatanumbers?.outputfromrsync?.count, count > 0 {
                pushremotedatanumbers?.maxpushpull = Double(count)
            }
            // Cleanup after all async work completes
            activeStreamingProcess = nil
            streamingHandlers = nil
            verifypath.removeAll()
            // Mark completed
            onComplete()
            if pushonly {
                verifypath.append(Verify(task: .pushviewonly))
            }
        }
    }

    func abort() {
        InterruptProcess()
    }
}

@Observable @MainActor
final class EstimatePush {
    let config: SynchronizeConfiguration
    let isadjusted: Bool
    let reduceestimatedcount: Int = 15

    // Streaming strong references
    var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?
    var pushremotedatanumbers: RemoteDataNumbers?
    var onComplete: () -> Void

    init(config: SynchronizeConfiguration, isadjusted: Bool, onComplete: @escaping () -> Void) {
        self.config = config
        self.isadjusted = isadjusted
        self.onComplete = onComplete
        streamingHandlers = nil
        activeStreamingProcess = nil
        pushremotedatanumbers = nil
    }

    // For check remote, pull remote data
    func pushRemote(config: SynchronizeConfiguration) {
        let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(dryRun: true,
                                                                                                         forDisplay: false,
                                                                                                         keepdelete: true)
        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { _ in },
            processTermination: { output, hiddenID in
                self.pushProcessTermination(stringoutputfromrsync: output, hiddenID: hiddenID)
            },
            cleanup: { self.activeStreamingProcess = nil; self.streamingHandlers = nil }
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
        Task {
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
            if isadjusted == false {
                // Create output for view
                let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
                pushremotedatanumbers?.outputfromrsync = out
            } else {
                pushremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: stringoutputfromrsync,
                                                          config: config)
            }
            if let count = pushremotedatanumbers?.outputfromrsync?.count, count > 0 {
                pushremotedatanumbers?.maxpushpull = Double(count)
            }
            // Cleanup after all async work completes
            activeStreamingProcess = nil
            streamingHandlers = nil
            // Mark completed
            onComplete()
        }
    }
}
