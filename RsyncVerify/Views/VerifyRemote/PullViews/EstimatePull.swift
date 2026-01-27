//
//  EstimatePull.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import Observation
import RsyncProcessStreaming

@Observable
@MainActor
final class EstimatePull {
    let config: SynchronizeConfiguration
    let reduceestimatedcount: Int = 15

    // Streaming strong references
    var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?
    var pullremotedatanumbers: RemoteDataNumbers?
    var onComplete: () -> Void

    init(config: SynchronizeConfiguration, onComplete: @escaping () -> Void) {
        self.config = config
        self.onComplete = onComplete
        streamingHandlers = nil
        activeStreamingProcess = nil
        pullremotedatanumbers = nil
    }

    /// For check remote, pull remote data
    func pullRemote(config: SynchronizeConfiguration) {
        let arguments = ArgumentsPullRemote(config: config).argumentspullremotewithparameters(
            dryRun: true,
            forDisplay: false,
            keepdelete: true
        )

        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { _ in },
            processTermination: { [weak self] output, hiddenID in
                guard let self else { return }
                Task { @MainActor in
                    await self.pullProcessTermination(
                        stringoutputfromrsync: output,
                        hiddenID: hiddenID
                    )
                }
            },
            cleanup: { [weak self] in
                Task { @MainActor in
                    self?.activeStreamingProcess = nil
                    self?.streamingHandlers = nil
                }
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

    func pullProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) async {
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

        let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
        pullremotedatanumbers?.outputfromrsync = out

        // Release current streaming before next task
        if let count = pullremotedatanumbers?.outputfromrsync?.count, count > 0 {
            pullremotedatanumbers?.maxpushpull = Double(count)
        }

        activeStreamingProcess = nil
        streamingHandlers = nil

        // Mark completed
        onComplete()
    }
}
