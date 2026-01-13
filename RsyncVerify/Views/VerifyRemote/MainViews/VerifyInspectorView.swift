//
//  VerifyInspectorView.swift
//  RsyncVerify
//
//  Created by GitHub Copilot on 12/01/2026.
//

import SwiftUI

struct VerifyInspectorView: View {
    @Binding var isadjusted: Bool
    @Binding var istagged: Bool
    @Binding var keepdelete: Bool
    @Binding var pushonly: Bool
    @Binding var pullonly: Bool

    let selectedconfig: SynchronizeConfiguration?

    var body: some View {
        VStack(alignment: .center) {
            
            Toggle("Tag output", isOn: $istagged)
                .toggleStyle(.switch)
                .padding(10)
            
            Toggle("Push only", isOn: $pushonly)
                .toggleStyle(.switch)
                .padding(10)

            Toggle("Pull only", isOn: $pullonly)
                .toggleStyle(.switch)
                .padding(10)
            
            Toggle("Keep delete", isOn: $keepdelete)
                .toggleStyle(.switch)
                .padding(10)
        
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        
}
