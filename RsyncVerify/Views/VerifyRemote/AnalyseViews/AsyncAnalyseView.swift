//
//  AsyncAnalyseView.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import SwiftUI

struct AsyncAnalyseView: View {
    let output: [RsyncOutputData]
    @State private var analyse: ActorRsyncOutputAnalyzer.AnalysisResult?

    var body: some View {
        Group {
            if let analyse {
                RsyncAnalysisView(analysisResult: analyse)
            } else {
                ProgressView()
            }
        }
        .task {
            analyse = await ActorRsyncOutputAnalyzer().analyze(output)
        }
    }
}
