//
//  PushPullDetailsView.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import OSLog
import SwiftUI

struct PushPullCombinedDetailsView: View {
    @Binding var verifypath: [Verify]
    
    let pushremotedatanumbers: RemoteDataNumbers?
    let pullremotedatanumbers: RemoteDataNumbers?
    let istagged: Bool
    
    
    var body: some View {
        HStack {
            PushDetailsSection(
                pushremotedatanumbers: pushremotedatanumbers,
                istagged: istagged,
                verifypath: $verifypath
            )
            
            PullDetailsSection(
                pullremotedatanumbers: pullremotedatanumbers,
                istagged: istagged,
                verifypath: $verifypath
            )
        }
    }
}

