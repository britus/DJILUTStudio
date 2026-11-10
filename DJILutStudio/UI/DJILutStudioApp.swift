import SwiftUI

@main
struct DJILutStudioApp: App {
    @State private var openedVideoURL: URL?

    init() {
        LUTLibraryStore.shared.prepare()
        ExportHistoryStore.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            StudioView(openedVideoURL: $openedVideoURL)
                .frame(minWidth: 1024, minHeight: 810)
                .onOpenURL { url in
                    guard url.isFileURL else { return }
                    openedVideoURL = url
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
