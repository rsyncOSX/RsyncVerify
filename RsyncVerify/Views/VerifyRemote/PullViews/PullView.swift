//
//  PullView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/01/2026.
//


import OSLog
import RsyncProcessStreaming
import SwiftUI
import Observation

struct PullView: View {
    @Binding var verifypath: [Verify]
    @Binding var pullremotedatanumbers: RemoteDataNumbers?
    @Binding var pullonly: Bool
    
    @State private var isaborted: Bool = false
    @State private var estimatePull: EstimatePull?
    
    let config: SynchronizeConfiguration
    let isadjusted: Bool
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            ProgressView()
            
            Text("Estimating \(config.backupID) PULL, please wait ...")
                .font(.title2)
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            startPullEstimation()
        }
        .toolbar(content: {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "stop.fill",
                    helpText: "Abort"
                ) {
                    isaborted = true
                    abort()
                }
            }
        })
    }
    
    private func startPullEstimation() {
        let estimate = EstimatePull(
            config: config,
            isadjusted: isadjusted,
            onComplete: { [self] in
                handlePullCompletion()
            }
        )
        
        estimatePull = estimate
        estimate.pullRemote(config: config)
    }
    
    private func handlePullCompletion() {
        Task { @MainActor in
            guard !isaborted else { return }
            
            // Update the binding with results from EstimatePull
            pullremotedatanumbers = estimatePull?.pullremotedatanumbers
            
            // Clear verification path
            verifypath.removeAll()
            
            // Mark completed
            onComplete()
            
            if pullonly {
                verifypath.append(Verify(task: .pullviewonly))
            }
            
            // Clean up
            estimatePull = nil
        }
    }
    
    func abort() {
        InterruptProcess()
        estimatePull?.activeStreamingProcess = nil
        estimatePull?.streamingHandlers = nil
        estimatePull = nil
    }
}

