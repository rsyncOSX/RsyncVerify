//
//  RsyncAnalysisView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 12/01/2026.
//

import SwiftUI

struct RsyncAnalysisView: View {
    let analysisResult: ActorRsyncOutputAnalyzer.AnalysisResult
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedChangeTypes: Set<ActorRsyncOutputAnalyzer.ChangeType> = []

    var body: some View {
        VStack(spacing: 0) {
            runTypeHeader

            TabView(selection: $selectedTab) {
                AnalysisOverviewView(
                    statistics: analysisResult.statistics,
                    itemizedChanges: analysisResult.itemizedChanges
                )
                .tag(0)

                AnalysisChangesView(
                    changes: analysisResult.itemizedChanges,
                    searchText: $searchText,
                    selectedChangeTypes: $selectedChangeTypes
                )
                .tag(1)

                AnalysisStatisticsView(statistics: analysisResult.statistics)
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
    }

    private var runTypeHeader: some View {
        HStack {
            Image(systemName: analysisResult.isDryRun ? "eye" : "checkmark.circle.fill")
                .foregroundColor(analysisResult.isDryRun ? .orange : .green)
            Text(analysisResult.isDryRun ? "DRY RUN (no changes made)" : "LIVE RUN")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(analysisResult.isDryRun ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
    }
}
