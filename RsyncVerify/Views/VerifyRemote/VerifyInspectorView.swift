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
    let selectedconfig: SynchronizeConfiguration?
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Toggle("Adjust output", isOn: $isadjusted)
                    .toggleStyle(.switch)
                    .padding(10)

                Toggle("Tag output", isOn: $istagged)
                    .toggleStyle(.switch)
                    .padding(10)

                Toggle("Keep delete", isOn: $keepdelete)
                    .toggleStyle(.switch)
                    .padding(10)
            }
            .padding()

            if let selectedconfig {
                RsyncCommandView(config: selectedconfig,
                                 keepdelete: keepdelete)
                    .padding()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}
