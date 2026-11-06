import SwiftUI
internal import AppKit
internal import UniformTypeIdentifiers

struct StudioView: View {
    private static let outputFolderBookmarkKey = "studio.outputFolderBookmark"

    private let catalog = LUTCatalog.load()
    @State private var videoURL: URL?
    @State private var videoHasSecurityScope = false
    @State private var selectedDevice = ""
    @State private var selectedLUT = ""
    @AppStorage("studio.selectedLook") private var selectedLook = "Natural Rec.709"
    @State private var outputFolder: URL?
    @State private var outputFolderHasSecurityScope = false
    @State private var codec = "HEVC"
    @AppStorage("studio.fineDetailSharpening") private var sharpen = false
    @State private var isProcessing = false
    @State private var status = "Bereit für deinen nächsten Clip"
    @State private var progress = 0.0
    @State private var showOutputPicker = false
    @State private var errorMessage: String?

    private var activeDevice: LUTDevice? { catalog.devices.first { $0.id == selectedDevice } }
    private var deviceLUTs: [LUTProfile] { activeDevice?.luts ?? [] }
    private var lutURL: URL? {
        guard let lut = catalog.allLUTs.first(where: { $0.id == selectedLUT }) else { return nil }
        return Bundle.main.resourceURL?.appending(path: "lut_library").appending(path: lut.file)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(DS.sidebarBorder).frame(width: 1)
            workspace
        }
        .background(DS.chatBg)
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showOutputPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: chooseOutput)
        .alert("Export fehlgeschlagen", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Unbekannter Fehler") }
            .onAppear(perform: restoreSettings)
            .onDisappear {
                if !isProcessing { stopSecurityScopes() }
            }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 11) {
                Image(systemName: "camera.aperture").font(.system(size: 21, weight: .semibold)).foregroundStyle(.cyan)
                    .frame(width: 40, height: 40).background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("DJI LUT STUDIO").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.0)
                    Text("COLOR WORKFLOW").font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(DS.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("WORKSPACE")
                sidebarItem("Color Grading", icon: "slider.horizontal.3", selected: true)
                sidebarItem("LUT Library", icon: "square.stack.3d.up")
                sidebarItem("Export History", icon: "clock.arrow.circlepath")
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("SYSTEM")
                Label("Native Export", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(DS.green)
                Label("Apple Silicon · Metal", systemImage: "cpu").foregroundStyle(DS.textSecondary)
            }.font(.system(size: 11, weight: .medium))
            Text("DJI LUT Studio 2.0 · macOS").font(.system(size: 10)).foregroundStyle(DS.textSecondary)
        }
        .padding(20).frame(width: 224).background(DS.sidebarBg)
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color Grading").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Bring your DJI footage to life.").font(.system(size: 12)).foregroundStyle(DS.textSecondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(DS.green).frame(width: 7, height: 7)
                    Text("NATIVE ENGINE READY").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.5)
                }.foregroundStyle(DS.textSecondary).padding(.horizontal, 12).padding(.vertical, 8).background(DS.buttonBg, in: Capsule())
            }.padding(.horizontal, 28).padding(.vertical, 20)
            Rectangle().fill(DS.divider).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    videoCard
                    HStack(alignment: .top, spacing: 16) { cameraCard; gradeCard }
                    exportCard
                    nativeExportCard
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(status).font(.system(size: 11, weight: .medium))
                            if isProcessing { ProgressView(value: progress).tint(.cyan).frame(width: 240) }
                        }
                        Spacer()
                        Button(action: startExport) {
                            HStack(spacing: 9) {
                                if isProcessing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles") }; Text(isProcessing ? "GRADING…" : "APPLY LUT & EXPORT")
                            }
                            .font(.system(size: 12, weight: .bold)).tracking(0.4).foregroundStyle(Color.black.opacity(0.9))
                            .padding(.horizontal, 20).frame(height: 44).background(LinearGradient(colors: [.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).disabled(videoURL == nil || outputFolder == nil || isProcessing)
                    }.padding(.top, 2)
                }.padding(24).frame(maxWidth: 1040).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - SOURCE FOOTAGE
    private var videoCard: some View {
        DS.Card(icon: "film", title: "SOURCE FOOTAGE", accent: .cyan) {
            // Wrap the button in a VStack so .onDrop does not swallow Button taps on macOS.
            VStack {
                Button {
                    presentVideoPicker()
                }
                label: {
                    HStack(spacing: 16) {
                        Image(systemName: videoURL == nil ? "plus.square.dashed" : "film.fill").font(.system(size: 25)).foregroundStyle(.cyan).frame(width: 58, height: 58).background(.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(videoURL?.lastPathComponent ?? "Drop a clip or browse files").font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.textPrimary)
                            Text(videoURL?.path ?? "MOV, MP4 or M4V · camera profile suggested from filename").font(.system(size: 11)).foregroundStyle(DS.textSecondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(videoURL == nil ? "BROWSE" : "CHANGE").font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(.cyan).padding(.horizontal, 12).padding(.vertical, 8).background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(DS.codeBg.opacity(0.45), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(DS.border.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: videoURL == nil ? [5, 4] : [])))
                }.buttonStyle(.plain).disabled(isProcessing)
            }
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { DispatchQueue.main.async { selectVideo(url) } } }
                return true
            }
        }
    }

    private var cameraCard: some View {
        DS.Card(icon: "camera", title: "CAMERA PROFILE", accent: .cyan) {
            VStack(alignment: .leading, spacing: 9) {
                Text("DEVICE").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.textSecondary)
                Picker("Device", selection: $selectedDevice) { ForEach(catalog.devices) { Text($0.name).tag($0.id) } }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedDevice) { _, _ in selectedLUT = activeDevice?.luts.first(where: { $0.recommended == true })?.id ?? activeDevice?.luts.first?.id ?? "" }
                Text("CONVERSION LUT").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.textSecondary).padding(.top, 4)
                Picker("LUT", selection: $selectedLUT) { ForEach(deviceLUTs) { Text($0.name).tag($0.id) } }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                if let lut = deviceLUTs.first(where: { $0.id == selectedLUT }), let description = lut.description {
                    Text(description).font(.system(size: 10)).foregroundStyle(DS.textSecondary).fixedSize(horizontal: false, vertical: true).lineLimit(3)
                }
            }
        }.frame(maxWidth: .infinity)
    }

    private var gradeCard: some View {
        DS.Card(icon: "slider.horizontal.3", title: "CREATIVE GRADE", accent: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                Text("LOOK").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.textSecondary)
                Picker("Look", selection: $selectedLook) { ForEach(["Natural Rec.709", "Vibrant Pop", "Cinematic Film", "Golden Hour", "Teal & Orange", "Moody Noir B&W"], id: \.self) { Text($0) } }.labelsHidden().pickerStyle(.menu)
                Toggle(isOn: $sharpen) { Label("Fine detail sharpening", systemImage: "viewfinder") }.toggleStyle(.switch)
                Label("Gyroflow stabilization", systemImage: "gyroscope").foregroundStyle(DS.textSecondary)
                Text("Gyroflow processing is not yet connected in this macOS port.").font(.system(size: 10)).foregroundStyle(DS.textSecondary)
            }.font(.system(size: 11))
        }.frame(maxWidth: .infinity)
    }

    private var exportCard: some View {
        DS.Card(icon: "square.and.arrow.up", title: "EXPORT SETTINGS", accent: .orange) {
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("FORMAT").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.textSecondary)
                    Picker("Codec", selection: $codec) { Text("HEVC · H.265").tag("HEVC"); Text("H.264").tag("H.264"); Text("ProRes 422").tag("ProRes"); Text("ProRes 422 HQ").tag("ProRes HQ") }.labelsHidden().pickerStyle(.menu).frame(width: 180, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("ENCODING").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.textSecondary)
                    Label("Apple high quality", systemImage: "sparkles").font(.system(size: 11)).foregroundStyle(DS.textPrimary)
                }
                Rectangle().fill(DS.divider).frame(width: 1, height: 38)
                VStack(alignment: .leading, spacing: 7) {
                    Text("DESTINATION").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(DS.textSecondary)
                    Button { showOutputPicker = true } label: {
                        Label(outputFolder?.lastPathComponent ?? "Choose folder", systemImage: "folder")
                        .lineLimit(1)
                        .foregroundStyle(outputFolder == nil ? DS.orange : DS.textPrimary)
                    }.buttonStyle(.plain).font(.system(size: 11)).disabled(isProcessing)
                }
                Spacer()
#if false
                Label("Comparison preview", systemImage: "rectangle.split.2x1").font(.system(size: 10)).foregroundStyle(DS.textSecondary)
#endif
            }
        }
    }

    // MARK: - NATIVE EXPORT
    private var nativeExportCard: some View {
        DS.Card(icon: "sparkles.rectangle.stack", title: "APPLE VIDEO ENGINE", accent: DS.green) {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(DS.green)
                    .frame(width: 44, height: 44)
                    .background(DS.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 5) {
                    Text("AVFoundation · Core Image")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.textPrimary)
                    Text("LUT grading, sharpening, encoding and audio export run natively on macOS.")
                        .font(.system(size: 11)).foregroundStyle(DS.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.codeBg.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(DS.border.opacity(0.8)))
        }
    }

    private func sectionLabel(_ text: String) -> some View { Text(text).font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(DS.textSecondary).padding(.leading, 8) }
    private func sidebarItem(_ title: String, icon: String, selected: Bool = false) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).frame(width: 16); Text(title); Spacer() }.font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? DS.textPrimary : DS.textSecondary).padding(.horizontal, 10).frame(height: 34)
            .background(selected ? DS.accentDim : .clear, in: RoundedRectangle(cornerRadius: 7))
    }

    private func setDefaults() {
        selectedDevice = catalog.devices.first(where: { $0.id == "o4" })?.id ?? catalog.devices.first?.id ?? ""
        selectedLUT = activeDevice?.luts.first(where: { $0.recommended == true })?.id ?? activeDevice?.luts.first?.id ?? ""
    }

    private func restoreSettings() {
        setDefaults()
        restoreOutputFolderBookmark()
    }

    private func presentVideoPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectVideo(url)
    }

    private func chooseOutput(_ result: Result<[URL], Error>) {
        guard !isProcessing else { return }
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = String(localized: "Access to the selected export folder was not granted. Select it again.")
            return
        }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: Self.outputFolderBookmarkKey)
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = String(localized: "The export folder selection could not be saved: \(error.localizedDescription)")
            return
        }

        if outputFolderHasSecurityScope { outputFolder?.stopAccessingSecurityScopedResource() }
        outputFolder = url
        outputFolderHasSecurityScope = true
    }

    private func restoreOutputFolderBookmark() {
        guard !outputFolderHasSecurityScope,
              let bookmark = UserDefaults.standard.data(forKey: Self.outputFolderBookmarkKey) else { return }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = String(localized: "Access to the saved export folder was not restored. Select the folder again.")
                return
            }

            if isStale {
                do {
                    let refreshedBookmark = try url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(refreshedBookmark, forKey: Self.outputFolderBookmarkKey)
                } catch {
                    url.stopAccessingSecurityScopedResource()
                    errorMessage = String(localized: "The saved export folder bookmark could not be refreshed.")
                    return
                }
            }

            outputFolder = url
            outputFolderHasSecurityScope = true
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.outputFolderBookmarkKey)
            errorMessage = String(localized: "The saved export folder is unavailable. Select it again.")
        }
    }
    private func selectVideo(_ url: URL) {
        guard !isProcessing else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = String(localized: "Access to the selected video was not granted. Choose it with Browse.")
            return
        }
        if videoHasSecurityScope { videoURL?.stopAccessingSecurityScopedResource() }
        videoURL = url
        videoHasSecurityScope = true
        let name = url.deletingPathExtension().lastPathComponent.uppercased()
        if let match = catalog.devices.first(where: { device in (device.filenamePatterns ?? []).contains(where: { name.contains($0.uppercased()) }) }) {
            selectedDevice = match.id
            selectedLUT = match.luts.first(where: { $0.recommended == true })?.id ?? match.luts.first?.id ?? ""
            status = "Detected \(match.name) from filename"
        } else { status = "Clip loaded · choose the matching camera profile" }
    }

    private func stopSecurityScopes() {
        if videoHasSecurityScope { videoURL?.stopAccessingSecurityScopedResource() }
        if outputFolderHasSecurityScope { outputFolder?.stopAccessingSecurityScopedResource() }
        videoHasSecurityScope = false
        outputFolderHasSecurityScope = false
    }

    private func startExport() {
        guard let videoURL, let lutURL else {
            errorMessage = String(localized: "The selected LUT resource could not be found.")
            return
        }
        guard let outputFolder else {
            showOutputPicker = true
            status = String(localized: "Choose an export folder to continue")
            return
        }

        isProcessing = true
        progress = 0
        status = String(localized: "Preparing native video export…")
        Task { @MainActor in
            do {
                let output = try await NativeVideoExporter.export(
                    videoURL: videoURL,
                    lutURL: lutURL,
                    outputFolder: outputFolder,
                    codec: codec,
                    sharpen: sharpen,
                    look: selectedLook,
                    progress: { value in
                        let safeProgress = value.isFinite ? min(max(value, 0), 1) : 0
                        progress = safeProgress
                        status = String(localized: "Color grading · \(Int(safeProgress * 100))%")
                    }
                )
                isProcessing = false
                progress = 1
                status = String(localized: "Export complete · \(output.lastPathComponent)")
            } catch {
                isProcessing = false
                status = String(localized: "Export failed")
                errorMessage = error.localizedDescription
            }
        }
    }
}
