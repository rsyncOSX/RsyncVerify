//
//  PushPullCommandtoDisplay.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/12/2024.
//

import Foundation

@MainActor
struct PushPullCommandtoDisplay {
    var command: String

    init(push: Bool,
         config: SynchronizeConfiguration,
         dryRun: Bool,
         keepdelete: Bool) {
        var str = ""
        if push == false {
            if config.offsiteServer.isEmpty == false, config.task == SharedReference.shared.synchronize {
                if let arguments = ArgumentsPullRemote(config: config).argumentspullremotewithparameters(
                    dryRun: dryRun,
                    forDisplay: true,
                    keepdelete: keepdelete
                ) {
                    str = (GetfullpathforRsync().rsyncpath()) + " " + arguments.joined()
                }
            } else {
                str = "Use macOS Finder"
            }
        } else {
            if config.offsiteServer.isEmpty == false, config.task == SharedReference.shared.synchronize {
                if let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(
                    dryRun: dryRun,
                    forDisplay: true,
                    keepdelete: keepdelete
                ) {
                    str = (GetfullpathforRsync().rsyncpath()) + " " + arguments.joined()
                }
            } else {
                str = "Use macOS Finder"
            }
        }

        command = str
    }
}
