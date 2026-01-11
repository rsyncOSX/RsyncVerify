//
//  ExecutePushPullView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/12/2024.
//

import RsyncProcessStreaming
import SwiftUI

struct ExecutePushPullView: View {
    @State private var showprogressview = false
    @State private var remotedatanumbers: RemoteDataNumbers?
    @Binding var pushpullcommand: PushPullCommand

    @State private var dryrun: Bool = true
    @State private var keepdelete: Bool = true

    @State private var progress: Double = 0
    @State private var max: Double = 0

    // Streaming strong references
    @State private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    @State private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?

    let config: SynchronizeConfiguration
    let pushorpullbool: Bool // True if pull data
    let rsyncpullmax: Double
    let rsyncpushmax: Double

    var body: some View {
        HStack {
            if let remotedatanumbers {
                DetailsView(remotedatanumbers: remotedatanumbers)
            } else {
                HStack {
                    executeview

                    if pushpullcommand == .pullRemote {
                        let totalPull = Double(rsyncpullmax)
                        SynchronizeProgressView(max: Double(rsyncpullmax),
                                                progress: min(Swift.max(progress, 0), totalPull),
                                                statusText: "Push data")
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                    } else {
                        let totalPush = Double(rsyncpushmax)
                        SynchronizeProgressView(max: Double(rsyncpushmax),
                                                progress: min(Swift.max(progress, 0), totalPush),
                                                statusText: "Pull data")
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .toolbar(content: {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "stop.fill",
                    helpText: "Abort"
                ) {
                    abort()
                }
            }
        })
    }

    var executeview: some View {
        VStack {
            HStack {
                if pushpullcommand == .pushLocal {
                    ConditionalGlassButton(
                        systemImage: "arrowshape.right.fill",
                        helpText: "Push to remote"
                    ) {
                        showprogressview = true
                        push(config: config)
                    }
                } else if pushpullcommand == .pullRemote {
                    ConditionalGlassButton(
                        systemImage: "arrowshape.left.fill",
                        helpText: "Pull from remote"
                    ) {
                        showprogressview = true
                        pull(config: config)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("--dry-run", isOn: $dryrun)
                        .toggleStyle(.switch)
                        .onTapGesture {
                            withAnimation(Animation.easeInOut(duration: true ? 0.35 : 0)) {
                                dryrun.toggle()
                            }
                        }

                    Toggle("--delete", isOn: $keepdelete)
                        .toggleStyle(.switch)
                        .onTapGesture {
                            withAnimation(Animation.easeInOut(duration: true ? 0.35 : 0)) {
                                keepdelete.toggle()
                            }
                        }
                        .help("Remove the delete parameter, default is true?")
                }
            }

            PushPullCommandView(pushpullcommand: $pushpullcommand,
                                dryrun: $dryrun,
                                keepdelete: $keepdelete,
                                config: config)
                .padding(10)
        }

        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(10)
    }

    // For a verify run, --dry-run
    func push(config: SynchronizeConfiguration) {
        let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(dryRun:
            dryrun,
            forDisplay: false,
            keepdelete: keepdelete)

        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: fileHandler,
            processTermination: { output, hiddenID in
                processTermination(stringoutputfromrsync: output, hiddenID: hiddenID)
            },
            cleanup: { activeStreamingProcess = nil; streamingHandlers = nil }
        )

        guard SharedReference.shared.norsync == false else { return }
        guard config.task != SharedReference.shared.halted else { return }
        guard let arguments else { return }
        guard let streamingHandlers else { return }

        let process = RsyncProcessStreaming.RsyncProcess(
            arguments: arguments,
            hiddenID: config.hiddenID,
            handlers: streamingHandlers,
            useFileHandler: true
        )
        do {
            try process.executeProcess()
            activeStreamingProcess = process
        } catch let err {
            let error = err
            SharedReference.shared.errorobject?.alert(error: error)
        }
    }

    func pull(config: SynchronizeConfiguration) {
        let arguments = ArgumentsPullRemote(config: config).argumentspullremotewithparameters(dryRun: dryrun,
                                                                                              forDisplay: false,
                                                                                              keepdelete: keepdelete)

        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: fileHandler,
            processTermination: { output, hiddenID in
                processTermination(stringoutputfromrsync: output, hiddenID: hiddenID)
            },
            cleanup: { activeStreamingProcess = nil; streamingHandlers = nil }
        )
        guard let arguments else { return }
        guard let streamingHandlers else { return }

        let process = RsyncProcessStreaming.RsyncProcess(
            arguments: arguments,
            hiddenID: config.hiddenID,
            handlers: streamingHandlers,
            useFileHandler: true
        )
        do {
            try process.executeProcess()
            activeStreamingProcess = process
        } catch let err {
            let error = err
            SharedReference.shared.errorobject?.alert(error: error)
        }
    }

    func processTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) {
        Task { @MainActor in
            showprogressview = false

            let lines = stringoutputfromrsync?.count ?? 0
            if dryrun {
                max = Double(lines)
            }

            if lines > SharedReference.shared.alerttagginglines, let stringoutputfromrsync {
                let suboutput = PrepareOutputFromRsync().prepareOutputFromRsync(stringoutputfromrsync)
                remotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: suboutput,
                                                      config: config)
            } else {
                remotedatanumbers = RemoteDataNumbers(stringoutputfromrsync: stringoutputfromrsync,
                                                      config: config)
            }

            let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
            remotedatanumbers?.outputfromrsync = out

            // Release streaming references to avoid retain cycles
            activeStreamingProcess = nil
            streamingHandlers = nil
        }
    }

    func fileHandler(count: Int) {
        DispatchQueue.main.async { progress = Double(count) }
    }

    func abort() {
        InterruptProcess()
    }
}
