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
    @Binding var pushorpull: ObservableVerifyRemotePushPull
    @Binding var verifypath: [Verify]
    @Binding var pushpullcommand: PushPullCommand
    // Pull data from remote, adjusted
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
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
        DispatchQueue.main.async {
            if (stringoutputfromrsync?.count ?? 0) > 20, let stringoutputfromrsync {
                let suboutput = PrepareOutputFromRsync().prepareOutputFromRsync(stringoutputfromrsync)
                pullremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: suboutput,
                                                          config: config)
            } else {
                pullremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: stringoutputfromrsync,
                                                          config: config)
            }
            guard isaborted == false else { return }
            // Rsync output pull
            pushorpull.rsyncpull = stringoutputfromrsync
            pushorpull.rsyncpullmax = (stringoutputfromrsync?.count ?? 0) - reduceestimatedcount
            if pushorpull.rsyncpullmax < 0 {
                pushorpull.rsyncpullmax = 0
            }
        }
        if isadjusted {
            // Adjust output
            pushorpull.adjustoutput()
            let adjustedPull = pushorpull.adjustedpull
            Task.detached { [adjustedPull] in
                async let outPull = ActorCreateOutputforView().createOutputForView(adjustedPull)
                let pull = await outPull
                await MainActor.run {
                    pullremotedatanumbers?.outputfromrsync = pull
                }
            }
        } else {
            Task.detached { [stringoutputfromrsync] in
                let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
                await MainActor.run { pullremotedatanumbers?.outputfromrsync = out }
            }
        }
        // Release current streaming before next task
        activeStreamingProcess = nil
        streamingHandlers = nil
        verifypath.removeAll()
    }

    func abort() {
        InterruptProcess()
    }
}
