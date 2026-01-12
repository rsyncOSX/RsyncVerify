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
    case analyseviewpush
    case analyseviewpull
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
    @State private var selectedtaskishalted: Bool = false
    @State private var isadjusted: Bool = false
    @State private var istagged: Bool = true
    @State private var keepdelete: Bool = false
    @State private var pushonly: Bool = false
    @State private var pullonly: Bool = false
    @State private var pushpullcommand = PushPullCommand.pushLocal
    @State private var verifypath: [Verify] = []
    @State var showinspector: Bool = false
    @State private var pullremotedatanumbers: RemoteDataNumbers?
    @State private var pushremotedatanumbers: RemoteDataNumbers?

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .inspector(isPresented: $showinspector) {
            VerifyInspectorView(
                isadjusted: $isadjusted,
                istagged: $istagged,
                keepdelete: $keepdelete,
                pushonly: $pushonly,
                pullonly: $pullonly,
                selectedconfig: selectedconfig)
            .inspectorColumnWidth(min: 400, ideal: 500, max: 600)
        }
        .toolbar {
            VerifyToolbarContent(
                pushandpullestimated: pushandpullestimated,
                disabledpushpull: disabledpushpull,
                selectedconfig: selectedconfig,
                selectedtaskishalted: selectedtaskishalted,
                showinspector: $showinspector,
                verifypath: $verifypath,
                pullremotedatanumbers: $pullremotedatanumbers,
                pushremotedatanumbers: $pushremotedatanumbers,
                selecteduuids: $selecteduuids,
                selectedconfigBinding: $selectedconfig,
                pushonly: $pushonly,
                pullonly: $pullonly
            )
        }
    }
    
    private var sidebarContent: some View {
        VStack {
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

            rsyncVersionMessage
        }
    }
    
    private var rsyncVersionMessage: some View {
        Group {
            if SharedReference.shared.rsyncversion3 {
                MessageView(mytext: SharedReference.shared.rsyncversionshort ?? "", size: .caption2)
            } else {
                MessageView(mytext: "Not applicable\nfor openrsync", size: .caption2)
            }
        }
    }
    
    private var detailContent: some View {
        NavigationStack(path: $verifypath) {
            if pushandpullestimated {
                PushPullDetailsView(
                    pushremotedatanumbers: pushremotedatanumbers,
                    pullremotedatanumbers: pullremotedatanumbers,
                    istagged: istagged,
                    verifypath: $verifypath
                )
            } else {
                configurationsTableView
            }
        }
        .navigationDestination(for: Verify.self) { which in
            makeView(view: which.task)
        }
    }
    
    private var configurationsTableView: some View {
        ConfigurationsTableDataView(
            selecteduuids: $selecteduuids,
            configurations: rsyncUIdata.configurations
        )
        .onChange(of: selecteduuids) {
            handleConfigurationSelection()
        }
    }
    
    private func handleConfigurationSelection() {
        guard let configurations = rsyncUIdata.configurations else { return }
        
        if let index = configurations.firstIndex(where: { $0.id == selecteduuids.first }) {
            guard selectedconfig?.task != SharedReference.shared.halted else { return }
            selectedconfig = configurations[index]
            showinspector = true
        } else {
            selectedconfig = nil
            showinspector = false
        }
    }

    @MainActor
    private func prepareadjustedoutput() {
        Task.detached { [pushremotedatanumbers, pullremotedatanumbers] in
            let reduceestimatedcount = 15

            let pushRaw = pushremotedatanumbers?.preparedoutputfromrsync
            let pullRaw = pullremotedatanumbers?.preparedoutputfromrsync

            var rsyncpushmax = (pushRaw?.count ?? 0) - reduceestimatedcount
            if rsyncpushmax < 0 { rsyncpushmax = 0 }

            var rsyncpullmax = (pullRaw?.count ?? 0) - reduceestimatedcount
            if rsyncpullmax < 0 { rsyncpullmax = 0 }

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
    private func makeView(view: DestinationVerifyView) -> some View {
        switch view {
        case let .executenpushpullview(configuuid):
            executePushPullView(for: configuuid)

        case let .pushview(configuuid):
            pushView(for: configuuid)

        case let .pullview(configuuid):
            pullView(for: configuuid)

        case .analyseviewpush:
            analyseView(for: pushremotedatanumbers)

        case .analyseviewpull:
            analyseView(for: pullremotedatanumbers)
        }
    }
    
    @ViewBuilder
    private func executePushPullView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let config = rsyncUIdata.configurations?[index] {
            ExecutePushPullView(
                pushpullcommand: $pushpullcommand,
                config: config,
                pushorpullbool: pushorpull(),
                rsyncpullmax: pullremotedatanumbers?.maxpushpull ?? 0,
                rsyncpushmax: pushremotedatanumbers?.maxpushpull ?? 0
            )
        }
    }
    
    @ViewBuilder
    private func pushView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let config = rsyncUIdata.configurations?[index] {
            PushView(
                verifypath: $verifypath,
                pushpullcommand: $pushpullcommand,
                pushremotedatanumbers: $pushremotedatanumbers,
                pushonly: $pushonly,
                config: config,
                isadjusted: isadjusted
            )
        }
    }
    
    @ViewBuilder
    private func pullView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let config = rsyncUIdata.configurations?[index] {
            PullView(
                verifypath: $verifypath,
                pushpullcommand: $pushpullcommand,
                pullremotedatanumbers: $pullremotedatanumbers,
                pushremotedatanumbers: $pushremotedatanumbers,
                pullonly: $pullonly,
                config: config,
                isadjusted: isadjusted
            )
            .onDisappear {
                if isadjusted && pullonly == false && pushonly == false {
                    prepareadjustedoutput()
                }
            }
        }
    }
    
    @ViewBuilder
    private func analyseView(for remotedatanumbers: RemoteDataNumbers?) -> some View {
        if let output = remotedatanumbers?.outputfromrsync {
            AsyncAnalyseView(output: output)
        }
    }

    private func pushorpull() -> Bool {
        if let pushcount = pushremotedatanumbers?.maxpushpull,
           let pullcount = pullremotedatanumbers?.maxpushpull {
            return pushcount > pullcount
        }
        return false
    }

    private var disabledpushpull: Bool {
        guard let selectedconfig else { return true }
        guard SharedReference.shared.rsyncversion3 else { return true }
        return selectedconfig.offsiteServer.isEmpty
    }

    private var pushandpullestimated: Bool {
        (pullremotedatanumbers?.outputfromrsync != nil &&
            pushremotedatanumbers?.outputfromrsync != nil)
    }
}
