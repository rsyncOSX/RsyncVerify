//
//  RsyncCommandtoDisplay.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 22.07.2017.
//

import Foundation

enum RsyncCommand: String, CaseIterable, Identifiable, CustomStringConvertible {
    case pushdata = "push_data"
    case pulldata = "pull_data"

    var id: String { rawValue }
    var description: String { rawValue.localizedCapitalized.replacingOccurrences(of: "_", with: " ") }
}

@MainActor
struct RsyncCommandtoDisplay {
    var rsynccommand: String

    init(display: RsyncCommand,
         config: SynchronizeConfiguration,
         keepdelete: Bool = false) {
        var str = ""
        switch display {
        case .pushdata:
            if config.task == SharedReference.shared.halted {
                str = "Task is halted"
            } else {
                if let arguments = ArgumentsSynchronize(config: config).argumentsforpushlocaltoremotewithparameters(dryRun: true,
                                                                                                                    forDisplay: true,
                                                                                                                    keepdelete: keepdelete) {
                    str = (GetfullpathforRsync().rsyncpath()) + " " + arguments.joined()
                }
            }
        case .pulldata:
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
