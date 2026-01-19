import Observation
import RsyncProcessStreaming
import SwiftUI

struct ExecutePullView: View {
    @Binding var keepdelete: Bool

    @State private var showprogressview = false
    @State private var remotedatanumbers: RemoteDataNumbers?
    @State private var dryrun: Bool = true

    @State private var progress: Double = 0
    @State private var max: Double = 0

    @State private var executionManager: PushPullExecutionManager?

    let selectedconfig: SynchronizeConfiguration
    let rsyncpullmax: Double

    var body: some View {
        HStack {
            if let remotedatanumbers {
                DetailsView(remotedatanumbers: remotedatanumbers)
            } else {
                HStack {
                    executeview

                    SynchronizeProgressView(max: Double(rsyncpullmax),
                                            progress: min(Swift.max(progress, 0), Double(rsyncpullmax)),
                                            statusText: "Pull Remote")
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
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
                ConditionalGlassButton(
                    systemImage: "arrowshape.left.fill",
                    helpText: "Pull from remote"
                ) {
                    showprogressview = true
                    executePull()
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
                .padding()
            }

            /*
             PushPullCommandView(pushpullcommand: pushpullcommand,
                                 dryrun: $dryrun,
                                 keepdelete: $keepdelete,
                                 config: selectedconfig)
                 .padding()
              */
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(10)
    }

    private func executePush() {
        executionManager = PushPullExecutionManager(
            config: selectedconfig,
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
            config: selectedconfig,
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
                config: selectedconfig
            )
        } else {
            remotedatanumbers = RemoteDataNumbers(
                stringoutputfromrsync: result.output,
                config: selectedconfig
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
