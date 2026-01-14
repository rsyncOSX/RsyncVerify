//
//  AsyncAnalyseView.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import SwiftUI
import RsyncAnalyse

struct AsyncAnalyseView: View {
    let output: [RsyncOutputData]
    @State private var analyse: ActorRsyncOutputAnalyser.AnalysisResult?

    var body: some View {
        Group {
            if let analyse {
                RsyncAnalysisView(analysisResult: analyse)
            } else {
                ProgressView()
            }
        }
        .task {
            guard !output.isEmpty else { return }
            let stringData = output.map(\.record).joined(separator: "\n")
            analyse = await ActorRsyncOutputAnalyser().analyze(stringData)
        }
    }
}

