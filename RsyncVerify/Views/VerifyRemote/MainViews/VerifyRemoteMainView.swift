//
//  VerifyRemoteMainView.swift
//  RsyncSwiftUI
//
//  Created by Thomas Evensen on 23/02/2021.
//

import OSLog
import SwiftUI

enum DestinationVerifyView: Hashable {
    /// PULL
    case executenpullview(configID: SynchronizeConfiguration.ID)
    // PUSH
    case executenpushview(configID: SynchronizeConfiguration.ID)
    case pushview(configID: SynchronizeConfiguration.ID)
    case pullview(configID: SynchronizeConfiguration.ID)
    case analyseviewpush
    case analyseviewpull
    case pushviewonly
    case pullviewonly
    case estimatepushandpullview(configID: SynchronizeConfiguration.ID)
}

struct Verify: Hashable, Identifiable {
    let id = UUID()
    var task: DestinationVerifyView
}

struct VerifyRemoteMainView: View {
    @Bindable var rsyncUIdata: RsyncVerifyconfigurations
    @Binding var selectedprofileID: ProfilesnamesRecord.ID?

    @State private var selecteduuids = Set<SynchronizeConfiguration.ID>()
    @State private var selectedconfig: SynchronizeConfiguration?
    @State private var selectedtaskishalted: Bool = false
    @State private var istagged: Bool = true
    @State private var keepdelete: Bool = false
    @State private var pushonly: Bool = false
    @State private var pullonly: Bool = false
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
                istagged: $istagged,
                keepdelete: $keepdelete,
                pushonly: $pushonly,
                pullonly: $pullonly,
                selectedconfig: selectedconfig
            )
            .inspectorColumnWidth(min: 200, ideal: 300, max: 350)
        }
        .toolbar {
            VerifyToolbarContent(
                pushandpullestimated: pushandpullestimated,
                disabledpushpull: disabledpushpull,
                selectedconfig: selectedconfig,
                verifypath: $verifypath,
                pullremotedatanumbers: $pullremotedatanumbers,
                pushremotedatanumbers: $pushremotedatanumbers,
                selecteduuids: $selecteduuids,
                selectedconfigBinding: $selectedconfig
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
            ZStack {
                if verifypath.isEmpty { configurationsTableView }

                if pushandpullestimated == false, selecteduuids.isEmpty == false {
                    ConditionalGlassButton(
                        systemImage: "play.fill",
                        helpText: "Verify selected"
                    ) {
                        guard let selectedconfig else { return }
                        guard selectedtaskishalted == false else { return }
                        guard SharedReference.shared.process == nil else { return }
                        showinspector = false
                        if pullonly {
                            verifypath.append(Verify(task: .pullview(configID: selectedconfig.id)))
                        } else if pushonly {
                            verifypath.append(Verify(task: .pushview(configID: selectedconfig.id)))
                        } else {
                            verifypath.append(Verify(task: .estimatepushandpullview(configID: selectedconfig.id)))
                        }
                    }
                    .disabled(disabledpushpull)
                }
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
            pullremotedatanumbers = nil
            pushremotedatanumbers = nil
            selecteduuids.removeAll()
            selectedconfig = nil
            verifypath.removeAll()
            showinspector = false
        }
    }

    @ViewBuilder
    private func makeView(view: DestinationVerifyView) -> some View {
        switch view {
        case let .executenpullview(configuuid):
            executePullView(for: configuuid) // PULL
        case let .executenpushview(configuuid):
            executePushView(for: configuuid) // PUSH
        case let .pushview(configuuid):
            pushView(for: configuuid)
        case let .pullview(configuuid):
            pullView(for: configuuid)
        case .analyseviewpush:
            analyseView(for: pushremotedatanumbers)
        case .analyseviewpull:
            analyseView(for: pullremotedatanumbers)
        case .pushviewonly:
            if let selectedconfig {
                PushDetailsSection(verifypath: $verifypath,
                                   selectedconfig: selectedconfig,
                                   pushremotedatanumbers: pushremotedatanumbers,
                                   istagged: istagged)
            }
        case .pullviewonly:
            if let selectedconfig {
                PullDetailsSection(verifypath: $verifypath,
                                   selectedconfig: selectedconfig,
                                   pullremotedatanumbers: pullremotedatanumbers,
                                   istagged: istagged)
            }
        case let .estimatepushandpullview(configuuid):
            estimatePushPullView(for: configuuid)
        }
    }

    @ViewBuilder
    private func estimatePushPullView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let config = rsyncUIdata.configurations?[index] {
            EstimatePushandPull(verifypath: $verifypath,
                                pushremotedatanumbers: $pushremotedatanumbers,
                                pullremotedatanumbers: $pullremotedatanumbers,
                                istagged: $istagged,
                                selectedconfig: config)
        }
    }

    /// Execute PULL
    @ViewBuilder
    private func executePullView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let selectedconfig = rsyncUIdata.configurations?[index] {
            ExecutePullView(
                keepdelete: $keepdelete,
                selectedconfig: selectedconfig,
                rsyncpullmax: pullremotedatanumbers?.maxpushpull ?? 0
            )
        }
    }

    /// Execute PUSH
    @ViewBuilder
    private func executePushView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let selectedconfig = rsyncUIdata.configurations?[index] {
            ExecutePushView(
                keepdelete: $keepdelete,
                selectedconfig: selectedconfig,
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
                pushremotedatanumbers: $pushremotedatanumbers,
                pushonly: $pushonly,
                config: config,
                onComplete: {}
            )
        }
    }

    @ViewBuilder
    private func pullView(for configuuid: SynchronizeConfiguration.ID) -> some View {
        if let index = rsyncUIdata.configurations?.firstIndex(where: { $0.id == configuuid }),
           let config = rsyncUIdata.configurations?[index] {
            PullView(
                verifypath: $verifypath,
                pullremotedatanumbers: $pullremotedatanumbers,
                pullonly: $pullonly,
                config: config,
                onComplete: {}
            )
        }
    }

    @ViewBuilder
    private func analyseView(for remotedatanumbers: RemoteDataNumbers?) -> some View {
        if let output = remotedatanumbers?.outputfromrsync {
            AsyncAnalyseView(output: output)
        }
    }

    private var disabledpushpull: Bool {
        guard let selectedconfig else { return true }
        guard SharedReference.shared.rsyncversion3 else { return true }
        return selectedconfig.offsiteServer.isEmpty
    }

    private var pushandpullestimated: Bool {
        (pullremotedatanumbers?.outputfromrsync != nil ||
            pushremotedatanumbers?.outputfromrsync != nil)
    }
}
