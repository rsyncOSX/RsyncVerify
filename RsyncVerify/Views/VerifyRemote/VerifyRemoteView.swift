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
    // Tag output or not
    @State private var istagged: Bool = false
    // Keep or remove delete
    @State private var keepdelete: Bool = false
    // @State private var pushorpull = ObservableVerifyRemotePushPull()
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

            if SharedReference.shared.rsyncversion3 {
                MessageView(mytext: SharedReference.shared.rsyncversionshort ?? "", size: .caption2)
            } else {
                MessageView(mytext: "Not applicable\nfor openrsync", size: .caption2)
            }

        } detail: {
            NavigationStack(path: $verifypath) {
                if pushandpullestimated {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Push")
                                    .font(.title2)
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(10)

                                ConditionalGlassButton(
                                    systemImage: "square.and.arrow.down.fill",
                                    helpText: "Save Push data to file"
                                ) {
                                    Task {
                                        if let output = pushremotedatanumbers?.outputfromrsync {
                                            Logger.process.debugMessageOnly("Execute: LOGGING details to logfile")
                                            _ = await ActorLogToFile().logOutput("PUSH output", output)
                                        }
                                    }
                                }

                                ConditionalGlassButton(
                                    systemImage: "questionmark.text.page.fill",
                                    helpText: "Analyze output from Push"
                                ) {
                                    Task {
                                        if let output = pushremotedatanumbers?.outputfromrsync {
                                            Logger.process.debugMessageOnly("Analysis: LOGGING details to logfile")
                                            let analyse = await ActorRsyncOutputAnalyzer().analyze(output)
                                            // _ = await ActorLogToFile().logOutput("Analysis PUSH output", analyse?.normalized())
                                        }
                                    }
                                }
                            }

                            if let pushremotedatanumbers {
                                DetailsVerifyView(remotedatanumbers: pushremotedatanumbers,
                                                   istagged: istagged)
                                    .padding(10)
                            }
                        }

                        VStack(alignment: .leading) {
                            HStack {
                                Text("Pull")
                                    .font(.title2)
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(10)

                                ConditionalGlassButton(
                                    systemImage: "square.and.arrow.down.fill",
                                    helpText: "Save Pull data to file"
                                ) {
                                    Task {
                                        if let output = pullremotedatanumbers?.outputfromrsync {
                                            Logger.process.debugMessageOnly("Execute: LOGGING details to logfile")
                                            _ = await ActorLogToFile().logOutput("PULL output", output)
                                        }
                                    }
                                }

                                ConditionalGlassButton(
                                    systemImage: "questionmark.text.page.fill",
                                    helpText: "Analyze output from Pull"
                                ) {
                                    Task {
                                        if let output = pullremotedatanumbers?.outputfromrsync {
                                            Logger.process.debugMessageOnly("Analysis: LOGGING details to logfile")
                                            let analyse = await ActorRsyncOutputAnalyzer().analyze(output)
                                            // _ = await ActorLogToFile().logOutput("Analysis PULL output", analyse?.normalized())
                                        }
                                    }
                                }
                            }

                            if let pullremotedatanumbers {
                                DetailsVerifyView(remotedatanumbers: pullremotedatanumbers,
                                                   istagged: istagged)
                                    .padding(10)
                            }
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
                .inspectorColumnWidth(min: 400, ideal: 500, max: 600)
        }
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem {
            if pushandpullestimated == false {
                ConditionalGlassButton(
                    systemImage: "arrow.up",
                    helpText: "Verify selected"
                ) {
                    guard let selectedconfig else { return }
                    guard selectedtaskishalted == false else { return }
                    guard SharedReference.shared.process == nil else { return }
                    showinspector = false
                    verifypath.append(Verify(task: .pushview(configID: selectedconfig.id)))
                }
                .disabled(disabledpushpull)
            }
        }

        ToolbarItem {
            Spacer()
        }

        if pushandpullestimated == true {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "figure.run",
                    helpText: "Excute"
                ) {
                    guard let selectedconfig else { return }
                    verifypath.append(Verify(task: .executenpushpullview(configID: selectedconfig.id)))
                }
                .disabled(disabledpushpull)
            }
        }

        ToolbarItem {
            Spacer()
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "trash.fill",
                helpText: "Reset"
            ) {
                pullremotedatanumbers = nil
                pushremotedatanumbers = nil
                selecteduuids.removeAll()
                selectedconfig = nil
                verifypath.removeAll()
            }
        }

        ToolbarItem {
            Spacer()
        }
    }

    var inspectorView: some View {
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

    @MainActor func prepareadjustedoutput() {
        Task.detached { [pushremotedatanumbers, pullremotedatanumbers] in
            // Capture raw outputs locally to avoid sending non-Sendable state across actors
            let reduceestimatedcount = 15

            let pushRaw = pushremotedatanumbers?.preparedoutputfromrsync
            let pullRaw = pullremotedatanumbers?.preparedoutputfromrsync

            var rsyncpushmax = (pushRaw?.count ?? 0) - reduceestimatedcount
            if rsyncpushmax < 0 { rsyncpushmax = 0 }

            var rsyncpullmax = (pullRaw?.count ?? 0) - reduceestimatedcount
            if rsyncpullmax < 0 { rsyncpullmax = 0 }

            // Create a local instance to perform adjustments off the main actor without touching view state
            let local = ObservableVerifyRemotePushPull()
            local.outputrsyncpushraw = pushRaw
            local.outputrsyncpullraw = pullRaw
            local.rsyncpushmax = rsyncpushmax
            local.rsyncpullmax = rsyncpullmax

            await local.adjustoutput()
            let adjustedPull = local.adjustedpull
            let adjustedPush = local.adjustedpush

            async let outPull = ActorCreateOutputforView().createOutputForView(adjustedPull)
            async let outPush = ActorCreateOutputforView().createOutputForView(adjustedPush)
            let (pull, push) = await (outPull, outPush)

            await MainActor.run {
                self.pullremotedatanumbers?.outputfromrsync = pull
                self.pushremotedatanumbers?.outputfromrsync = push
            }
        }
    }

    @ViewBuilder
    func makeView(view: DestinationVerifyView) -> some View {
        switch view {
        case let .executenpushpullview(configuuid):
            if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }) {
                if let config = rsyncUIdata.configurations?[index] {
                    ExecutePushPullView(pushpullcommand: $pushpullcommand,
                                        config: config,
                                        pushorpullbool: pushorpull(),
                                        rsyncpullmax: pullremotedatanumbers?.maxpushpull ?? 0,
                                        rsyncpushmax: pushremotedatanumbers?.maxpushpull ?? 0)
                }
            }

        case let .pushview(configuuid):
            if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }) {
                if let config = rsyncUIdata.configurations?[index] {
                    PushView(verifypath: $verifypath,
                             pushpullcommand: $pushpullcommand,
                             pushremotedatanumbers: $pushremotedatanumbers,
                             config: config,
                             isadjusted: isadjusted)
                }
            }

        case let .pullview(configuuid):
            if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }) {
                if let config = rsyncUIdata.configurations?[index] {
                    PullView(verifypath: $verifypath,
                             pushpullcommand: $pushpullcommand,
                             pullremotedatanumbers: $pullremotedatanumbers,
                             pushremotedatanumbers: $pushremotedatanumbers,
                             config: config,
                             isadjusted: isadjusted)
                        .onDisappear {
                            if isadjusted {
                                prepareadjustedoutput()
                            }
                        }
                }
            }
        }
    }

    func pushorpull() -> Bool {
        if let pushcount = pushremotedatanumbers?.maxpushpull, let pullcount = pullremotedatanumbers?.maxpushpull {
            return pushcount > pullcount
        }
        return false
    }

    var disabledpushpull: Bool {
        guard let selectedconfig else { return true }
        guard SharedReference.shared.rsyncversion3 else { return true }
        return selectedconfig.offsiteServer.isEmpty
    }

    var pushandpullestimated: Bool {
        (pullremotedatanumbers?.outputfromrsync != nil &&
            pushremotedatanumbers?.outputfromrsync != nil)
    }
}
