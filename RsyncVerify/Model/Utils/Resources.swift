//
//  Resources.swift
//  RsyncVerify
//

import Foundation

/// Enumtype type of resource
enum ResourceType {
    case changelog
    case documents
    case urlJSON
}

struct Resources {
    /// Resource strings
    private var urlJSON: String = "https://raw.githubusercontent.com/rsyncOSX/RsyncVerify/master/" +
        "versionRsyncVerify/versionRsyncVerify.json"
    /// Get the resource.
    func getResource(resource _: ResourceType) -> String {
        urlJSON
    }
}
