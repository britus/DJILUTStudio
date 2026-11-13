import SwiftUI
internal import AppKit

enum StudioWorkspace: String, Identifiable, Hashable {
    case grading, library, history, bookmarks, about

    var id: String { rawValue }
}

struct MenuFileCommands: Commands {
    @Binding var workspace: StudioWorkspace?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            EmptyView()
        }
        CommandGroup(replacing: .saveItem) {
            EmptyView()
        }
        CommandGroup(replacing: .importExport) {
            EmptyView()
        }
    }
}

struct MenuEditCommands: Commands {
    @Binding var workspace: StudioWorkspace?

    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            EmptyView()
        }
        CommandGroup(replacing: .textFormatting) {
            EmptyView()
        }
    }
}

struct MenuViewCommands: Commands {
    @Binding var workspace: StudioWorkspace?

    var body: some Commands {
        CommandGroup(replacing: .windowArrangement) {
            EmptyView()
        }
        CommandGroup(replacing: .sidebar) {
            EmptyView()
        }
    }
}

struct MenuHelpCommands: Commands {
    @Binding var workspace: StudioWorkspace?
    @Binding var showUserGuide: Bool

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Divider()
            Button(String(localized: "User guide")) {
                showUserGuide = true
            }
            Divider()
            Button(String(localized: "About")) {
                workspace = .about
            }
        }
    }
}

@main
struct DJILutStudioApp: App {
    @State private var openedVideoURL: URL?
    @State private var workspace: StudioWorkspace? = .grading

    @AppStorage("studio.showUserGuide") private var showUserGuide = true

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
        LUTLibraryStore.shared.prepare()
        ExportHistoryStore.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            StudioView(openedVideoURL: $openedVideoURL, workspace: $workspace, showUserGuide: $showUserGuide)
                .frame(minWidth: 1024, minHeight: 810)
                .onOpenURL { url in
                    guard url.isFileURL else { return }
                    openedVideoURL = url
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            MenuFileCommands(workspace: $workspace)
            MenuEditCommands(workspace: $workspace)
            MenuViewCommands(workspace: $workspace)
            MenuHelpCommands(workspace: $workspace, showUserGuide: $showUserGuide)
        }
    }
}
