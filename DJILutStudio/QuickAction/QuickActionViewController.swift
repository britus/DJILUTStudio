import AppKit
import UniformTypeIdentifiers

private final class ExtensionContextBox: @unchecked Sendable {
    let context: NSExtensionContext

    init(_ context: NSExtensionContext) {
        self.context = context
    }
}

final class QuickActionViewController: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let inputItems = context.inputItems.compactMap { $0 as? NSExtensionItem }
        let providers = inputItems.flatMap { $0.attachments ?? [] }
        let supportedTypes = [UTType.movie, .video]
        guard let match = providers.lazy.compactMap({ provider in
            supportedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) })
                .map { (provider, $0) }
        }).first else {
            context.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnsupportedSchemeError))
            return
        }

        let contextBox = ExtensionContextBox(context)
        match.0.loadItem(forTypeIdentifier: match.1.identifier, options: nil) { [contextBox] item, _ in
            guard let url = item as? URL else {
                Task { @MainActor in
                    contextBox.context.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError))
                }
                return
            }
            Task { @MainActor in
                Self.openInMainApp(url, context: contextBox.context)
            }
        }
    }

    @MainActor
    private static func openInMainApp(_ videoURL: URL, context: NSExtensionContext) {
        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        let contextBox = ExtensionContextBox(context)
        NSWorkspace.shared.open([videoURL], withApplicationAt: appURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    contextBox.context.cancelRequest(withError: error)
                } else {
                    contextBox.context.completeRequest(returningItems: nil)
                }
            }
        }
    }
}
