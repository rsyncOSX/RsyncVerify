//
//  VerifyRemoteView.swift
//  RsyncSwiftUI
//
//  Created by Thomas Evensen on 23/02/2021.
//

import OSLog
import SwiftUI

enum DestinationVerifyView: Hashable {
    case executenpushpullview(configID: SynchronizeConfiguration.ID)
    case pushview(configID: SynchronizeConfiguration.ID)
    case pullview(configID: SynchronizeConfiguration.ID)
}

struct Verify: Hashable, Identifiable {
    let id = UUID()
    var task: DestinationVerifyView
}

struct VerifyRemoteView: View {
    @Bindable var rsyncUIdata: RsyncVerifyconfigurations
    @Binding var selectedprofileID: ProfilesnamesRecord.ID?

    @State private var selecteduuids = Set<SynchronizeConfiguration.ID>()
    @State private var selectedconfig: SynchronizeConfiguration?
    // Selected task is halted
    @State private var selectedtaskishalted: Bool = false
    // Adjusted output rsync
    @State private var isadjusted: Bool = false
    // Decide push or pull
    @State private var pushorpull = ObservableVerifyRemotePushPull()
    @State private var pushpullcommand = PushPullCommand.pushLocal
    @State private var verifypath: [Verify] = []
    // Show Inspector view
    @State var showinspector: Bool = false
    // Pull data from remote, adjusted
    @State private var pullremotedatanumbers: RemoteDataNumbers?
    // Push data to remote, adjusted
    @State private var pushremotedatanumbers: RemoteDataNumbers?

    var body: some View {
        NavigationSplitView {
            // Only show profile picker if there are other profiles
            // Id default only, do not show profile picker

            Picker("", selection: $selectedprofileID) {
                Text("Default")
                    .tag(nil as ProfilesnamesRecord.ID?)
                ForEach(rsyncUIdata.validprofiles, id: \.self) { profile in
                    Text(profile.profilename)
                        .tag(profile.id)
                }
            }
            .frame(width: 180)
            .padding([.bottom, .top, .trailing], 7)

            Spacer()

        } detail: {
            NavigationStack(path: $verifypath) {
                if let pullremotedatanumbers, let pushremotedatanumbers {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("PUSH")
                            DetailsVerifyView(remotedatanumbers: pushremotedatanumbers)
                                .padding(10)
                        }
                            
                        VStack(alignment: .leading) {
                            Text("PULL")
                            DetailsVerifyView(remotedatanumbers: pullremotedatanumbers)
                                .padding(10)
                        }
                    }
                } else {
                    ConfigurationsTableDataView(selecteduuids: $selecteduuids,
                                                configurations: rsyncUIdata.configurations)
                        .onChange(of: selecteduuids) {
                            if let configurations = rsyncUIdata.configurations {
                                if let index = configurations.firstIndex(where: { $0.id == selecteduuids.first }) {
                                    guard selectedconfig?.task != SharedReference.shared.halted else { return }
                                    selectedconfig = configurations[index]
                                    showinspector = true
                                } else {
                                    selectedconfig = nil
                                    showinspector = false
                                }
                            }
                        }
                }
            }.navigationDestination(for: Verify.self) { which in
                makeView(view: which.task)
            }
        }
        .inspector(isPresented: $showinspector) {
            inspectorView
                .inspectorColumnWidth(min: 100, ideal: 200, max: 300)
        }
    }

    var inspectorView: some View {
        VStack(alignment: .center) {
            if selecteduuids.count == 1, selectedconfig != nil {
                ConditionalGlassButton(
                    systemImage: "arrow.right",
                    helpText: "Verify selected"
                ) {
                    guard let selectedconfig else { return }
                    guard selectedtaskishalted == false else { return }
                    guard SharedReference.shared.process == nil else { return }
                    showinspector = false
                    verifypath.append(Verify(task: .pushview(configID: selectedconfig.id)))
                }
                .padding(10)
            }

            Toggle("Adjust output", isOn: $isadjusted)
                .toggleStyle(.switch)
                .padding(10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    @MainActor @ViewBuilder
    func makeView(view: DestinationVerifyView) -> some View {
        switch view {
        case let .executenpushpullview(configuuid):
            if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }) {
                if let config = rsyncUIdata.configurations?[index] {
                    ExecutePushPullView(pushorpull: $pushorpull,
                                        pushpullcommand: $pushpullcommand,
                                        config: config)
                }
            }

        case let .pushview(configuuid):
            if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }) {
                if let config = rsyncUIdata.configurations?[index] {
                    PushView(pushorpull: $pushorpull,
                             verifypath: $verifypath,
                             pushpullcommand: $pushpullcommand,
                             pushremotedatanumbers: $pushremotedatanumbers,
                             config: config,
                             isadjusted: isadjusted)
                }
            }

        case let .pullview(configuuid):
            if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }) {
                if let config = rsyncUIdata.configurations?[index] {
                    PullView(pushorpull: $pushorpull,
                             verifypath: $verifypath,
                             pushpullcommand: $pushpullcommand,
                             pullremotedatanumbers: $pullremotedatanumbers,
                             pushremotedatanumbers: $pushremotedatanumbers,
                             config: config,
                             isadjusted: isadjusted)
                }
            }
        }
    }
}

/*
 
 // Rsync output push
 pushorpull.rsyncpush = stringoutputfromrsync
 pushorpull.rsyncpushmax = (stringoutputfromrsync?.count ?? 0) - reduceestimatedcount
 if pushorpull.rsyncpushmax < 0 {
     pushorpull.rsyncpushmax = 0
 }
 
 // Rsync output pull
 pushorpull.rsyncpull = stringoutputfromrsync
 pushorpull.rsyncpullmax = (stringoutputfromrsync?.count ?? 0) - reduceestimatedcount
 if pushorpull.rsyncpullmax < 0 {
     pushorpull.rsyncpullmax = 0
 }
 
 if isadjusted {
     // Adjust output
     pushorpull.adjustoutput()
     let adjustedPull = pushorpull.adjustedpull
     let adjustedPush = pushorpull.adjustedpush
     
     Task.detached { [adjustedPull, adjustedPush] in
         async let outPull = ActorCreateOutputforView().createOutputForView(adjustedPull)
         async let outPush = ActorCreateOutputforView().createOutputForView(adjustedPush)
         let (pull, push) = await (outPull, outPush)
         await MainActor.run {
             pullremotedatanumbers?.outputfromrsync = pull
             pushremotedatanumbers?.outputfromrsync = push
         }
     }
 */
