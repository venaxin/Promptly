import SwiftUI
import AppKit

@main
struct PromptlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We don't actually use the default SwiftUI window;
        // we manage our own NSWindow in AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
