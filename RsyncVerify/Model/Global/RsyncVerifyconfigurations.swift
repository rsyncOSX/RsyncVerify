//
//  RsyncVerifyconfigurations.swift
//  RsyncVerify
//

import Observation
import SwiftUI

struct ProfilesnamesRecord: Identifiable, Equatable, Hashable {
    var profilename: String
    let id = UUID()

    init(_ name: String) {
        profilename = name
    }
}

@Observable @MainActor
final class RsyncVerifyconfigurations {
    var configurations: [SynchronizeConfiguration]?
    var profile: String?
    /// This is observed when URL actions are initiated.
    /// Before commence the real action must be sure that selected profile data is loaded from store
    @ObservationIgnored var validprofiles: [ProfilesnamesRecord] = []

    init() {}
}
