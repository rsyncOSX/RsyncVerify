import OSLog
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_: Notification) {}
}

@main
struct RsyncVerifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showabout: Bool = false

    var body: some Scene {
        Window("RsyncVerify", id: "main") {
            RsyncVerifyView()
                .frame(minWidth: 1250, minHeight: 550)
                .sheet(isPresented: $showabout) { AboutView() }
                .onDisappear {
                    // Quit the app when the main window is closed
                    performCleanupTask()
                    NSApplication.shared.terminate(nil)
                }
        }
        .commands {
            SidebarCommands()
           
            CommandGroup(replacing: .appInfo) {
                ConditionalGlassButton(
                    systemImage: "",
                    text: "About RsyncVerify",
                    helpText: "About"
                ) {
                    showabout = true
                }
            }
        }

        Settings {
            
            SidebarSettingsView()
        }
    }

    private func performCleanupTask() {
        Logger.process.debugMessageOnly("RsyncVerifyApp: performCleanupTask(), RsyncVerify shutting down, doing clean up")
        SharedReference.shared.checkeandterminateprocess()
    }
}

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier
    static let process = Logger(subsystem: subsystem ?? "process", category: "process")

    func errorMessageOnly(_ message: String) {
        #if DEBUG
            error("\(message)")
        #endif
    }

    func debugMessageOnly(_ message: String) {
        #if DEBUG
            debug("\(message)")
        #endif
    }

    func debugThreadOnly(_ message: String) {
        #if DEBUG
            if Thread.checkIsMainThread() {
                debug("\(message) Running on main thread")
            } else {
                debug("\(message) NOT on main thread, currently on \(Thread.current)")
            }
        #endif
    }
}
