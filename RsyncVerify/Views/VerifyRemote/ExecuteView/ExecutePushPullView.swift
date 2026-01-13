import Observation
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

    @State private var executionManager: PushPullExecutionManager?

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
        .onChange(of: executionManager?.progress) { _, newValue in
            if let newValue {
                progress = newValue
            }
        }
        .onChange(of: executionManager?.remotedatanumbers) { _, newValue in
            if let newValue {
                remotedatanumbers = newValue
                showprogressview = false
            }
        }
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
                        executePush()
                    }
                } else if pushpullcommand == .pullRemote {
                    ConditionalGlassButton(
                        systemImage: "arrowshape.left.fill",
                        helpText: "Pull from remote"
                    ) {
                        showprogressview = true
                        executePull()
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

    private func executePush() {
        executionManager = PushPullExecutionManager(
            config: config,
            dryrun: dryrun,
            keepdelete: keepdelete
        )

        // Update progress when manager's progress changes
        executionManager?.onProgressUpdate = { newProgress in
            Task { @MainActor in
                progress = newProgress
            }
        }

        executionManager?.onCompletion = { result in
            Task { @MainActor in
                handleCompletion(result: result)
            }
        }

        executionManager?.executePush()
    }

    private func executePull() {
        executionManager = PushPullExecutionManager(
            config: config,
            dryrun: dryrun,
            keepdelete: keepdelete
        )

        executionManager?.onProgressUpdate = { newProgress in
            Task { @MainActor in
                progress = newProgress
            }
        }

        executionManager?.onCompletion = { result in
            Task { @MainActor in
                handleCompletion(result: result)
            }
        }

        executionManager?.executePull()
    }

    private func handleCompletion(result: PushPullExecutionResult) {
        showprogressview = false

        // Update max if it's a dry run
        if dryrun {
            max = Double(result.linesCount)
        }

        // Create remote data numbers based on output
        if result.linesCount > SharedReference.shared.alerttagginglines,
           let output = result.output {
            let suboutput = PrepareOutputFromRsync().prepareOutputFromRsync(output)
            remotedatanumbers = RemoteDataNumbers(
                stringoutputfromrsync: suboutput,
                config: config
            )
        } else {
            remotedatanumbers = RemoteDataNumbers(
                stringoutputfromrsync: result.output,
                config: config
            )
        }

        // Set the output for view if available
        if let viewOutput = result.viewOutput {
            remotedatanumbers?.outputfromrsync = viewOutput
        }

        // Clean up
        executionManager = nil
    }

    func abort() {
        InterruptProcess()
        executionManager?.abort()
        executionManager = nil
    }
}
