//
//  PushPullExecutionManager.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

// MARK: - Supporting Types

import Observation
import RsyncProcessStreaming

struct PushPullExecutionResult {
    let output: [String]?
    let viewOutput: [RsyncOutputData]? // Changed from [String] to [RsyncOutputData]
    let linesCount: Int
}

// MARK: - Observable Execution Manager

@Observable
@MainActor
final class PushPullExecutionManager {
    let config: SynchronizeConfiguration
    let dryrun: Bool
    let keepdelete: Bool

    // Streaming references
    private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?

    // State
    var progress: Double = 0
    var remotedatanumbers: RemoteDataNumbers?

    // Callbacks
    var onProgressUpdate: ((Double) -> Void)?
    var onCompletion: ((PushPullExecutionResult) -> Void)?

    init(config: SynchronizeConfiguration, dryrun: Bool, keepdelete: Bool) {
        self.config = config
        self.dryrun = dryrun
        self.keepdelete = keepdelete
    }

    func executePush() {
        let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(
            dryRun: dryrun,
            forDisplay: false,
            keepdelete: keepdelete
        )

        setupStreamingHandlers()

        guard SharedReference.shared.norsync == false else { return }
        guard config.task != SharedReference.shared.halted else { return }
        guard let arguments, let streamingHandlers else { return }

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
            cleanup()
        }
    }

    func executePull() {
        let arguments = ArgumentsPullRemote(config: config).argumentspullremotewithparameters(
            dryRun: dryrun,
            forDisplay: false,
            keepdelete: keepdelete
        )

        setupStreamingHandlers()

        guard SharedReference.shared.norsync == false else { return }
        guard config.task != SharedReference.shared.halted else { return }
        guard let arguments, let streamingHandlers else { return }

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
            cleanup()
        }
    }

    private func setupStreamingHandlers() {
        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { [weak self] count in
                Task { @MainActor in
                    let progress = Double(count)
                    self?.progress = progress
                    self?.onProgressUpdate?(progress)
                }
            },
            processTermination: { [weak self] output, hiddenID in
                Task { @MainActor in
                    await self?.handleProcessTermination(
                        stringoutputfromrsync: output,
                        hiddenID: hiddenID
                    )
                }
            },
            cleanup: { [weak self] in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        )
    }

    private func handleProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) async {
        let linesCount = stringoutputfromrsync?.count ?? 0

        // Create view output asynchronously - this returns [RsyncOutputData]
        let viewOutput = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)

        // Create the result
        let result = PushPullExecutionResult(
            output: stringoutputfromrsync,
            viewOutput: viewOutput, // This is now [RsyncOutputData]
            linesCount: linesCount
        )

        // Call completion handler
        onCompletion?(result)

        // Clean up
        cleanup()
    }

    private func cleanup() {
        activeStreamingProcess = nil
        streamingHandlers = nil
    }

    func abort() {
        InterruptProcess()
        cleanup()
    }
}
