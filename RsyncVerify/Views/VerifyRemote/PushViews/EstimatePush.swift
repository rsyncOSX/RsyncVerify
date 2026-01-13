//
//  EstimatePush.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 13/01/2026.
//

import Observation
import RsyncProcessStreaming

@Observable
@MainActor
final class EstimatePush {
    let config: SynchronizeConfiguration
    let reduceestimatedcount: Int = 15

    // Streaming strong references
    var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?
    var pushremotedatanumbers: RemoteDataNumbers?
    var onComplete: () -> Void

    init(config: SynchronizeConfiguration, onComplete: @escaping () -> Void) {
        self.config = config
        self.onComplete = onComplete
        streamingHandlers = nil
        activeStreamingProcess = nil
        pushremotedatanumbers = nil
    }

    // For check remote, push remote data
    func pushRemote(config: SynchronizeConfiguration) {
        let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(
            dryRun: true,
            forDisplay: false,
            keepdelete: true
        )

        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { _ in },
            processTermination: { [weak self] output, hiddenID in
                guard let self else { return }
                Task { @MainActor in
                    await self.pushProcessTermination(
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
    func pushProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) async {
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

        let out = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)
        pushremotedatanumbers?.outputfromrsync = out

        // Set maxpushpull if we have output
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
