//
//  RsyncCommandView.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 07/01/2021.
//

import SwiftUI

struct RsyncCommandView: View {
    @State var selectedrsynccommand: PushPullCommand = .pushLocal

    let config: SynchronizeConfiguration
    let keepdelete: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Push and Pull\ncommand strings")

                Picker("", selection: $selectedrsynccommand) {
                    ForEach(PushPullCommand.allCases) { Text($0.description)
                        .tag($0)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .padding(10)
            }

            showcommandrsync
                .padding(10)
        }
        .padding(10)
    }

    var showcommandrsync: some View {
        Text(commandstringrsync ?? "")
            .textSelection(.enabled)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue, lineWidth: 1)
            )
    }

    var commandstringrsync: String? {
        RsyncCommandtoDisplay(display: selectedrsynccommand,
                              config: config,
                              keepdelete: keepdelete).rsynccommand
    }
}
