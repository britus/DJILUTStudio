import Foundation

struct LUTCatalog: Codable {
    var version: String?
    var name: String?
    var description: String?
    var categories: [LUTCategory]

    var deviceCategories: [LUTCategory] {
        categories.filter { $0.id != "cinematic_looks" }
    }

    var devices: [LUTDevice] {
        deviceCategories.flatMap(\.devices)
    }

    var allLUTs: [LUTProfile] {
        devices.flatMap(\.luts)
    }

    var lookProfiles: [LUTProfile] {
        categories.first(where: { $0.id == "cinematic_looks" })?.devices
            .first(where: { $0.id == "creative_looks" })?.luts ?? []
    }

    static func load(from url: URL? = nil) -> LUTCatalog {
        guard let url = url ?? Bundle.main.url(forResource: "lut_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(LUTCatalog.self, from: data) else {
            return LUTCatalog(categories: [])
        }
        return catalog
    }
}

struct LUTCategory: Codable, Identifiable {
    var id: String
    var name: String
    var devices: [LUTDevice]
}

struct LUTDevice: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var defaultProfile: String?
    var filenamePatterns: [String]?
    var luts: [LUTProfile]
    
    enum CodingKeys: String, CodingKey {
        case id, name, luts
        case defaultProfile = "default_profile"
        case filenamePatterns = "filename_patterns"
    }
}

struct LUTProfile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var type: String?
    var file: String
    var recommended: Bool?
    var description: String?
    var sourceBookmark: Data?

    func fileURL(in libraryDirectory: URL) -> URL {
        if let sourceBookmark {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: sourceBookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return resolved
            }
        }
        if file.hasPrefix("/") { return URL(fileURLWithPath: file) }
        return libraryDirectory.appending(path: file)
    }

    func isAvailable(in libraryDirectory: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(in: libraryDirectory).path)
    }
}
