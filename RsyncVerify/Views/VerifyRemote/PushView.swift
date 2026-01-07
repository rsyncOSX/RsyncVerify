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
        VStack {
            if let pushremotedatanumbers {
                VStack {
                    Text(" \(config.backupID)")
                        .font(.title2)

                    HStack {
                        VStack {
                            ConditionalGlassButton(
                                systemImage: "arrowshape.right.fill",
                                helpText: "Push local"
                            ) {
                                pushpullcommand = .pushLocal
                                verifypath.removeAll()
                                verifypath.append(Verify(task: .executenpushpullview(configID: config.id)))
                            }
                            .padding(10)

                            DetailsVerifyView(remotedatanumbers: pushremotedatanumbers)
                                .padding(10)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
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
        DispatchQueue.main.async {
            if (stringoutputfromrsync?.count ?? 0) > 20, let stringoutputfromrsync {
                let suboutput = PrepareOutputFromRsync().prepareOutputFromRsync(stringoutputfromrsync)
                pushremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: suboutput,
                                                          config: config)
            } else {
                pushremotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: stringoutputfromrsync,
                                                          config: config)
            }

            // Rsync output push
            pushorpull.rsyncpush = stringoutputfromrsync
            pushorpull.rsyncpushmax = (stringoutputfromrsync?.count ?? 0) - reduceestimatedcount
            if pushorpull.rsyncpushmax < 0 {
                pushorpull.rsyncpushmax = 0
            }
        }

        if isadjusted {
            // Adjust output
            pushorpull.adjustoutput()
            let adjustedPush = pushorpull.adjustedpush
            Task.detached { [adjustedPush] in
                async let outPush = ActorCreateOutputforView().createOutputForView(adjustedPush)
                let push = await outPush
                await MainActor.run {
                    pushremotedatanumbers?.outputfromrsync = push
                }
            }
        } else {
            Task.detached { [stringoutputfromrsync] in
                let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
                await MainActor.run { pushremotedatanumbers?.outputfromrsync = out }
            }
        }
        // Final cleanup
        activeStreamingProcess = nil
        streamingHandlers = nil
    }

    func abort() {
        InterruptProcess()
    }
}
