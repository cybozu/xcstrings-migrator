import Foundation

struct XCStrings: Codable, Equatable {
    var sourceLanguage: String
    var strings: [String: Strings]
    var version: String
}

struct Strings: Codable, Equatable {
    var localizations: [String: Localization]
}

struct Localization: Codable, Equatable {
    var stringUnit: StringUnit?
    var variations: Variations?
    
    init(stringUnit: StringUnit? = nil, variations: Variations? = nil) {
        self.stringUnit = stringUnit
        self.variations = variations
    }
}

struct Variations: Codable, Equatable {
    var plural: [String: PluralVariation]?
    
    init(plural: [String: PluralVariation]? = nil) {
        self.plural = plural
    }
}

struct PluralVariation: Codable, Equatable {
    var stringUnit: StringUnit
    
    init(stringUnit: StringUnit) {
        self.stringUnit = stringUnit
    }
}

struct StringUnit: Codable, Equatable {
    var state: String
    var value: String

    init(state: String = "translated", value: String) {
        self.state = state
        self.value = value
    }
}
