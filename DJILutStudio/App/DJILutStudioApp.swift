import SwiftUI

@main
struct DJILutStudioApp: App {
    var body: some Scene {
        WindowGroup {
            StudioView()
                .frame(minWidth: 980, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
