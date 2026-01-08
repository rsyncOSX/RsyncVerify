//
//  ObservableVerifyRemotePushPull.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 16/12/2024.
//

import OSLog

@Observable
final class ObservableVerifyRemotePushPull {
    @ObservationIgnored var adjustedpull: Set<String>?
    @ObservationIgnored var adjustedpush: Set<String>?

    @ObservationIgnored var outputrsyncpullraw: [String]?
    @ObservationIgnored var outputrsyncpushraw: [String]?

    @ObservationIgnored var rsyncpullmax: Int = 0
    @ObservationIgnored var rsyncpushmax: Int = 0

    @concurrent
    nonisolated func adjustoutput() async {
        Logger.process.debugThreadOnly("ObservableVerifyRemotePushPull: adjustoutput()")
        if var pullremote = outputrsyncpullraw,
           var pushremote = outputrsyncpushraw {
            guard pullremote.count > 15, pushremote.count > 15 else { return }

            pullremote.removeFirst()
            pushremote.removeFirst()
            pullremote.removeLast(15)
            pushremote.removeLast(15)

            // Pull data <<--
            var setpullremote = Set(pullremote.compactMap { row in
                row.hasSuffix("/") == false ? row : nil
            })
            setpullremote.subtract(pushremote.compactMap { row in
                row.hasSuffix("/") == false ? row : nil
            })

            adjustedpull = setpullremote

            // Push data -->>
            var setpushremote = Set(pushremote.compactMap { row in
                row.hasSuffix("/") == false ? row : nil
            })
            setpushremote.subtract(pullremote.compactMap { row in
                row.hasSuffix("/") == false ? row : nil
            })

            adjustedpush = setpushremote
        }
    }

    deinit {
        Logger.process.debugMessageOnly("ObservablePushPull: DEINIT")
    }
}
