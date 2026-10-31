import Foundation

struct LUTCatalog: Decodable {
    var categories: [LUTCategory]
    var devices: [LUTDevice] { categories.flatMap(\.devices) }
    var allLUTs: [LUTProfile] { devices.flatMap(\.luts) }

    static func load() -> LUTCatalog {
        guard let url = Bundle.main.url(forResource: "lut_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(LUTCatalog.self, from: data) else {
            return LUTCatalog(categories: [])
        }
        return catalog
    }
}

struct LUTCategory: Decodable, Identifiable {
    var id: String
    var name: String
    var devices: [LUTDevice]
}

struct LUTDevice: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var defaultProfile: String?
    var filenamePatterns: [String]?
    var luts: [LUTProfile]
    enum CodingKeys: String, CodingKey { case id, name, luts; case defaultProfile = "default_profile"; case filenamePatterns = "filename_patterns" }
}

struct LUTProfile: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var type: String?
    var file: String
    var recommended: Bool?
    var description: String?
}
