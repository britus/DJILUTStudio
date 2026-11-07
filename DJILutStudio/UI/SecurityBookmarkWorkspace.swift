import SwiftUI
internal import AppKit

struct SecurityFolderBookmark: Codable, Identifiable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    let data: Data
}

@MainActor
final class SecurityBookmarkStore: ObservableObject {
    static let shared = SecurityBookmarkStore()
    @Published private(set) var folders: [SecurityFolderBookmark] = []
    private let key = "studio.securityFolderBookmarks"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode([SecurityFolderBookmark].self, from: data) else { return }
        folders = stored
    }

    func addDirectory(_ url: URL) {
        let directory = url.standardizedFileURL
        guard !folders.contains(where: { $0.path == directory.path }),
              let data = try? directory.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        folders.append(SecurityFolderBookmark(path: directory.path, name: directory.lastPathComponent, data: data))
        save()
    }

    func remove(_ folder: SecurityFolderBookmark) {
        folders.removeAll { $0.id == folder.id }
        save()
    }

    func resolve(_ folder: SecurityFolderBookmark) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: folder.data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            folders.removeAll { $0.id == folder.id }
            save()
            return nil
        }
        if stale { addDirectory(url) }
        return url
    }

    func startAccessingDirectory(containing fileURL: URL) -> URL? {
        let filePath = fileURL.standardizedFileURL.path
        let candidates = folders
            .filter { filePath.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }
            .sorted { $0.path.count > $1.path.count }
        for folder in candidates {
            guard let directory = resolve(folder) else { continue }
            if directory.startAccessingSecurityScopedResource() { return directory }
        }
        return nil
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct SecurityBookmarkWorkspace: View {
    @ObservedObject private var store = SecurityBookmarkStore.shared
    let onOpenVideo: (URL) -> Void
    @State private var selection = Set<String>()

    var body: some View {
        VStack(spacing: 0) {
            DS.workspaceHeader(title: String(localized: "Security Bookmarks"),
                               subtitle: String(localized: "Manage folders and open media from a bookmarked directory."),
                               icon: "folder.badge.gearshape") {
                Button { addFolder() } label: { Label("Add Folder", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(.cyan)
            }

            if store.folders.isEmpty {
                ContentUnavailableView("No bookmarked folders", systemImage: "folder.badge.plus",
                                       description: Text("Add a folder to keep access to its media files."))
            } else {
                Table(store.folders, selection: $selection) {
                    TableColumn("Folder") { folder in
                        Label(folder.name, systemImage: "folder.fill").lineLimit(1)
                    }
                    TableColumn("Location") { folder in
                        Text(folder.path).foregroundStyle(DS.textSecondary).lineLimit(1).truncationMode(.middle)
                    }
                    TableColumn("Actions") { folder in
                        HStack(spacing: 10) {
                            Button { browse(folder) } label: { Label("Browse Files", systemImage: "film") }
                                .buttonStyle(.borderless)
                            Button(role: .destructive) { store.remove(folder) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Remove folder bookmark")
                        }
                    }
                }
                .padding(20)
            }
            
            Spacer()
        }
        .background(DS.chatBg)
        .onChange(of: store.folders) { _, _ in selection = selection.intersection(Set(store.folders.map(\.id))) }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add a bookmarked folder")
        panel.prompt = String(localized: "Bookmark Folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { store.addDirectory(url) }
    }

    private func browse(_ folder: SecurityFolderBookmark) {
        guard let directory = store.resolve(folder), directory.startAccessingSecurityScopedResource() else { return }
        defer { directory.stopAccessingSecurityScopedResource() }
        let panel = NSOpenPanel()
        panel.directoryURL = directory
        panel.allowedContentTypes = [.movie, .video]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { onOpenVideo(url) }
    }
}
