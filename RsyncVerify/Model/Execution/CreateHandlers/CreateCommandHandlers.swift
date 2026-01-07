//
//  CreateCommandHandlers.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 17/11/2025.
//

import Foundation
import ProcessCommand

@MainActor
struct CreateCommandHandlers {
    func createcommandhandlers(
        processTermination: @escaping ([String]?, Bool) -> Void

    ) -> ProcessHandlersCommand {
        ProcessHandlersCommand(
            processtermination: processTermination,
            checklineforerror: TrimOutputFromRsync().checkForRsyncError(_:),
            updateprocess: SharedReference.shared.updateprocess,
            propogateerror: { error in
                SharedReference.shared.errorobject?.alert(error: error)
            },
            logger: { _, _ in },
            rsyncui: true
        )
    }
}
