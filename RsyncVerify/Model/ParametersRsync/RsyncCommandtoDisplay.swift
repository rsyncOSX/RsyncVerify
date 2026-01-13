//
//  RsyncCommandtoDisplay.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 22.07.2017.
//

import Foundation

@MainActor
struct RsyncCommandtoDisplay {
    var rsynccommand: String

    init(display: PushPullCommand,
         config: SynchronizeConfiguration,
         keepdelete: Bool = false) {
        var str = ""
        switch display {
        case .pushLocal:
            if config.task == SharedReference.shared.halted {
                str = "Task is halted"
            } else {
                if let arguments = ArgumentsSynchronize(config: config)
                    .argumentsforpushlocaltoremotewithparameters(
                        dryRun: true,
                        forDisplay: true,
                        keepdelete: keepdelete
                    ) {
                    str = (GetfullpathforRsync().rsyncpath()) + " " + arguments.joined()
                }
            }
        case .pullRemote:
            if let arguments = ArgumentsPullRemote(config:
                config).argumentspullremotewithparameters(dryRun: true,
                                                          forDisplay: true,
                                                          keepdelete: keepdelete) {
                str = (GetfullpathforRsync().rsyncpath()) + " " + arguments.joined()
            }
        }
        rsynccommand = str
    }
}
