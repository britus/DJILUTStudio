import SwiftUI
internal import UniformTypeIdentifiers

@MainActor
final class LUTLibraryStore: ObservableObject {
    static let shared = LUTLibraryStore()
    @Published private(set) var files: [URL] = []
    @Published private(set) var catalog = LUTCatalog(categories: [])
    let rootURL: URL
    let manifestURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        rootURL = support.appendingPathComponent("DJILUTStudio/LUTLibrary", isDirectory: true)
        manifestURL = support.appendingPathComponent("DJILUTStudio/lut_manifest.json")
        refresh()
    }

    func prepare() {
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: manifestURL.path),
               let bundledManifest = Bundle.main.url(forResource: "lut_manifest", withExtension: "json") {
                try FileManager.default.copyItem(at: bundledManifest, to: manifestURL)
            }
            if let bundled = Bundle.main.resourceURL?.appendingPathComponent("lut_library"),
               let enumerator = FileManager.default.enumerator(at: bundled, includingPropertiesForKeys: nil) {
                for case let source as URL in enumerator where source.pathExtension.lowercased() == "cube" {
                    let relative = String(source.path.dropFirst(bundled.path.count + 1))
                    let destination = rootURL.appendingPathComponent(relative)
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if !FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.copyItem(at: source, to: destination)
                    }
                }
            }
            if let bundledLooks = Bundle.main.resourceURL?.appendingPathComponent("lut_looks"),
               let enumerator = FileManager.default.enumerator(at: bundledLooks, includingPropertiesForKeys: nil) {
                for case let source as URL in enumerator where source.pathExtension.lowercased() == "cube" {
                    let relative = String(source.path.dropFirst(bundledLooks.deletingLastPathComponent().path.count + 1))
                    let destination = rootURL.appendingPathComponent(relative)
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if !FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.copyItem(at: source, to: destination)
                    }
                }
            }
        } catch { NSLog("Could not prepare LUT library: %@", error.localizedDescription) }
        refresh()
    }

    func refresh() {
        catalog = LUTCatalog.load(from: manifestURL)
        files = Array(Set((catalog.allLUTs + catalog.lookProfiles)
            .map { $0.fileURL(in: rootURL) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }))
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func add(source: URL, name: String, details: String, category: LUTEntryCategory, storage: LUTStorageChoice, deviceName: String) throws {
        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }
        var profileFile: String
        var sourceBookmark: Data?
        if storage == .copy {
            let folder = category == .cinematicLooks ? "custom_looks" : "custom_conversion"
            let destination = uniqueDestination(for: source.lastPathComponent, subdirectory: folder)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
            profileFile = String(destination.path.dropFirst(rootURL.path.count + 1))
        } else {
            profileFile = source.path
            sourceBookmark = try source.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }

        let profile = LUTProfile(id: "user_\(UUID().uuidString.lowercased())", name: name, type: category == .cinematicLooks ? "creative" : "technical", file: profileFile, recommended: false, description: details.isEmpty ? nil : details, sourceBookmark: sourceBookmark)
        var updated = catalog
        if category == .cinematicLooks {
            if let categoryIndex = updated.categories.firstIndex(where: { $0.id == "cinematic_looks" }),
               let deviceIndex = updated.categories[categoryIndex].devices.firstIndex(where: { $0.id == "creative_looks" }) {
                updated.categories[categoryIndex].devices[deviceIndex].luts.append(profile)
            }
        } else {
            let categoryID = "user_added_devices"
            let deviceID = "user_" + deviceName.lowercased().replacingOccurrences(of: " ", with: "_")
            if let categoryIndex = updated.categories.firstIndex(where: { $0.id == categoryID }) {
                if let deviceIndex = updated.categories[categoryIndex].devices.firstIndex(where: { $0.id == deviceID }) {
                    updated.categories[categoryIndex].devices[deviceIndex].luts.append(profile)
                } else {
                    updated.categories[categoryIndex].devices.append(LUTDevice(id: deviceID, name: deviceName, defaultProfile: nil, filenamePatterns: nil, luts: [profile]))
                }
            } else {
                updated.categories.append(LUTCategory(id: categoryID, name: "User Added Devices", devices: [LUTDevice(id: deviceID, name: deviceName, defaultProfile: nil, filenamePatterns: nil, luts: [profile])]))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: manifestURL, options: .atomic)
        refresh()
    }

    func add(_ urls: [URL]) {
        for source in urls where source.pathExtension.lowercased() == "cube" {
            let didAccess = source.startAccessingSecurityScopedResource()
            defer { if didAccess { source.stopAccessingSecurityScopedResource() } }
            let destination = uniqueDestination(for: source.lastPathComponent)
            do { try FileManager.default.copyItem(at: source, to: destination) }
            catch { NSLog("Could not import LUT: %@", error.localizedDescription) }
        }
        refresh()
    }

    func delete(_ url: URL) {
        guard url.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path + "/") else { return }
        do { try FileManager.default.removeItem(at: url); refresh() }
        catch { NSLog("Could not delete LUT: %@", error.localizedDescription) }
    }

    private func uniqueDestination(for name: String, subdirectory: String = "") -> URL {
        let directory = subdirectory.isEmpty ? rootURL : rootURL.appendingPathComponent(subdirectory, isDirectory: true)
        var destination = directory.appendingPathComponent(name)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent) \(suffix).cube")
            suffix += 1
        }
        return destination
    }
}

enum LUTEntryCategory: String, CaseIterable, Identifiable { case conversion, cinematicLooks; var id: Self { self } }
enum LUTStorageChoice: String, CaseIterable, Identifiable { case copy, reference; var id: Self { self } }

struct LUTLibraryWorkspace: View {
    @ObservedObject private var library = LUTLibraryStore.shared
    @State private var showAddSheet = false
    @State private var selectedFile: URL?

    var body: some View {
        VStack(spacing: 0) {
            DS.workspaceHeader(title: "LUT Library",
                               subtitle: "Browse available color transforms.",
                               icon: "square.stack.3d.up") {
                Spacer()
                Button { showAddSheet = true } label: { Label("Add LUT's", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(.cyan)
            }
            if library.files.isEmpty {
                ContentUnavailableView("No LUT files", systemImage: "cube.transparent", description: Text("Add .cube LUT files to your library."))
            } else {
                List(selection: $selectedFile) {
                    ForEach(library.files, id: \.path) { file in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "cube.transparent").foregroundStyle(.cyan).frame(width: 34, height: 34).background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.deletingPathExtension().lastPathComponent).font(.system(size: 13, weight: .semibold))
                                Text(file.deletingLastPathComponent().lastPathComponent + " CUBE LUT").font(.system(size: 11))
                                    .foregroundStyle(DS.textSecondary)
                            }
                            Spacer()
                            Button {
                                selectedFile = file
                            } label: {
                                Image(systemName: "eye")
                            }
                            .buttonStyle(.plain)
                            .help("Preview LUT file")
                            /*
                             Button(role: .destructive) {
                             library.delete(file); selectedFile = nil } label: { Image(systemName: "trash")
                             }
                             .buttonStyle(.plain)
                             .help("Delete LUT")
                             */
                        }.padding(.vertical, 5)
                    }
                }
                .listStyle(.bordered)
            }
        }
        .background(DS.chatBg)
        .sheet(isPresented: $showAddSheet) { LUTEntrySheet { source, name, details, category, storage, deviceName in
            try library.add(source: source, name: name, details: details, category: category, storage: storage, deviceName: deviceName)
        } }
        .sheet(item: Binding(get: { selectedFile.map(LUTFileSelection.init(url:)) }, set: { selectedFile = $0?.url })) { selection in
            LUTPreviewSheet(url: selection.url)
        }
    }
}

private struct LUTEntrySheet: View {
    let saveEntry: (URL, String, String, LUTEntryCategory, LUTStorageChoice, String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var category: LUTEntryCategory = .conversion
    @State private var storage: LUTStorageChoice = .copy
    @State private var name = ""
    @State private var details = ""
    @State private var deviceName = ""
    @State private var sourceURL: URL?
    @State private var showImporter = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            DS.workspaceHeader(title: String(localized: "Add LUT to Library"),
                               subtitle: String(localized: "Add a conversion LUT or a cinematic look."),
                               icon: "cube.transparent") {
                EmptyView()
            }

            VStack(alignment: .leading, spacing: 14) {
                DS.Card(icon: "square.grid.2x2", title: String(localized: "LUT CATEGORY"), accent: .cyan) {
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Category", selection: $category) {
                                Text("Device / Conversion").tag(LUTEntryCategory.conversion)
                                Text("Cinematic Looks").tag(LUTEntryCategory.cinematicLooks)
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }

                DS.Card(icon: "text.alignleft", title: String(localized: "LUT DETAILS"), accent: .purple) {
                    HStack {
                        VStack(spacing: 12) {
                            if category == .conversion {
                                TextField("Device / Camera name", text: $deviceName)
                            }
                            TextField("LUT name", text: $name)
                            TextField("Description (optional)", text: $details)
                        }
                        Spacer()
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                }

                DS.Card(icon: "externaldrive", title: String(localized: "FILE STORAGE"), accent: .orange) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Store LUT", selection: $storage) {
                                Text("Copy to Application Support").tag(LUTStorageChoice.copy)
                                Text("Link to original file").tag(LUTStorageChoice.reference)
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                        }
                        Spacer()
                        Button {
                            showImporter = true
                        }
                        label: {
                            Label(sourceURL?.lastPathComponent ?? "Choose .cube file…",
                                  systemImage: "doc.badge.plus")
                            .lineLimit(1).truncationMode(.middle)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.red).font(.caption)
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack {
                Divider()
                HStack(alignment: .center, spacing: 12) {
                    Spacer()
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Add LUT") { save() }
                        .buttonStyle(.borderedProminent).tint(.cyan).keyboardShortcut(.defaultAction)
                        .disabled(sourceURL == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (category == .conversion && deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .frame(width: 560, height: 620)
        .background(DS.chatBg)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result { sourceURL = urls.first; if name.isEmpty { name = urls.first?.deletingPathExtension().lastPathComponent ?? "" } }
        }
    }

    private func save() {
        guard let sourceURL else { return }
        do {
            try saveEntry(sourceURL, name.trimmingCharacters(in: .whitespacesAndNewlines), details.trimmingCharacters(in: .whitespacesAndNewlines), category, storage, deviceName.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct LUTFileSelection: Identifiable { let url: URL; var id: String { url.path }; init(url: URL) { self.url = url } }

private struct LUTCubeMetadata: Sendable {
    let title: String?
    let dimension: Int?
    let oneDimensionalSize: Int?
    let domainMinimum: String
    let domainMaximum: String
    let colorEntries: Int
    let format: String

    static func read(from url: URL) throws -> LUTCubeMetadata {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var title: String?
        var dimension: Int?
        var oneDimensionalSize: Int?
        var domainMinimum = "0 0 0"
        var domainMaximum = "1 1 1"
        var colorEntries = 0

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !line.isEmpty else { continue }
            let fields = line.split(whereSeparator: \.isWhitespace)
            switch fields.first {
            case "TITLE":
                let value = line.dropFirst("TITLE".count).trimmingCharacters(in: .whitespacesAndNewlines)
                title = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            case "LUT_3D_SIZE" where fields.count == 2: dimension = Int(fields[1])
            case "LUT_1D_SIZE" where fields.count == 2: oneDimensionalSize = Int(fields[1])
            case "DOMAIN_MIN" where fields.count == 4: domainMinimum = fields.dropFirst().joined(separator: " ")
            case "DOMAIN_MAX" where fields.count == 4: domainMaximum = fields.dropFirst().joined(separator: " ")
            default:
                if fields.count == 3, fields.allSatisfy({ Float($0) != nil }) { colorEntries += 1 }
            }
        }

        return LUTCubeMetadata(title: title, dimension: dimension, oneDimensionalSize: oneDimensionalSize, domainMinimum: domainMinimum, domainMaximum: domainMaximum, colorEntries: colorEntries, format: dimension == nil ? "1D LUT" : "3D LUT")
    }
}

private struct LUTPreviewSheet: View {
    let url: URL
    @State private var metadata: LUTCubeMetadata?
    @State private var error: String?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "cube.transparent").font(.system(size: 22)).foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(metadata?.title ?? url.deletingPathExtension().lastPathComponent).font(.system(size: 17, weight: .semibold))
                    Text("CUBE \(metadata?.format ?? "LUT")").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(DS.textSecondary)
                }
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
            }

            if let metadata {
                Form {
                    metadataRow("Format", metadata.format)
                    if let dimension = metadata.dimension { metadataRow("3D LUT size", "\(dimension) × \(dimension) × \(dimension)") }
                    if let size = metadata.oneDimensionalSize { metadataRow("1D LUT size", "\(size) entries") }
                    metadataRow("Domain minimum", metadata.domainMinimum)
                    metadataRow("Domain maximum", metadata.domainMaximum)
                    metadataRow("Color entries", metadata.colorEntries.formatted())
                    metadataRow("File", url.path)
                }
                .formStyle(.grouped)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.codeBg.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            } else if let error {
                ContentUnavailableView("Unable to read LUT", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if isLoading {
                ProgressView("Please wait, reading LUT metadata.").frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(minHeight: 300)
        .frame(width: 560)
        .task(id: url) {
            isLoading = true
            metadata = nil
            error = nil
            let didAccess = url.startAccessingSecurityScopedResource()
            do {
                metadata = try await Task.detached(priority: .userInitiated) { try LUTCubeMetadata.read(from: url) }.value
            } catch {
                self.error = error.localizedDescription
            }
            if didAccess { url.stopAccessingSecurityScopedResource() }
            isLoading = false
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func metadataRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value).font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(6)
                .help(value)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(DS.textSecondary)

    }
}

