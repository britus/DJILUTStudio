import SwiftUI

@main
struct DJILutStudioApp: App {
    init() {
        LUTLibraryStore.shared.prepare()
        ExportHistoryStore.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            StudioView()
                .frame(minWidth: 980, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
