import AppKit
import FreeMyMacOSCore
import SwiftUI

/// Lets the menu ask the window to clean, so the menu goes through the same confirmation
/// as the Clean button.
@MainActor @Observable
final class CommandActions {
    /// Bumped by the menu; RootView reacts to it.
    var cleanRequests = 0
}

enum Links {
    static let website = URL(string: "https://freemymacos.com")!
    static let issues = URL(string: "https://github.com/biggypanda/FreeMyMacOS/issues")!
    static let latestRelease = URL(string: "https://github.com/biggypanda/FreeMyMacOS/releases/latest")!
}

/// Menu bar: a Clean menu and row selection in Edit, with keyboard shortcuts, Check for Updates, and Help links.
/// The app makes no network requests; the links open in the browser.
struct AppCommands: Commands {
    let model: AppModel
    let actions: CommandActions

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { NSWorkspace.shared.open(Links.latestRelease) }
        }

        CommandMenu("Clean") {
            Button("Rescan") { Task { await model.scan() } }
                .keyboardShortcut("r")
                .disabled(!(model.phase == .ready || model.phase == .idle))
            Button("Clean Selected") { actions.cleanRequests += 1 }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!(model.phase == .ready && model.selectedBytes > 0))
        }

        // The window has no text to edit, so Edit's Select All selects rows instead.
        CommandGroup(replacing: .pasteboard) {
            Button("Select All") { model.selectAll() }
                .keyboardShortcut("a")
                .disabled(model.phase != .ready)
            Button("Select None") { model.selectNone() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(model.phase != .ready)
        }

        CommandGroup(replacing: .help) {
            Button("\(Brand.name) Website") { NSWorkspace.shared.open(Links.website) }
            Button("Report a Problem…") { NSWorkspace.shared.open(Links.issues) }
            Button("Release Notes") { NSWorkspace.shared.open(Links.latestRelease) }
        }
    }
}
