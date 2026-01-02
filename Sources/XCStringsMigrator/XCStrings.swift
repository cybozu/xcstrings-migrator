import Foundation

struct XCStrings: Codable, Equatable {
    var sourceLanguage: String
    var strings: [String: Strings]
    var version: String

    struct Strings: Codable, Equatable {
        var localizations: [String: Localization]

        enum Localization: Codable, Equatable {
            case stringUnit(StringUnit)
            case variations(Variations)
        }
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

struct Variations: Codable, Equatable {
    var plural: [String: PluralVariation]

    struct PluralVariation: Codable, Equatable {
        var stringUnit: StringUnit
    }
}

extension XCStrings.Strings.Localization {
    enum CodingKeys: CodingKey {
        case stringUnit
        case variations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringUnit = try container.decodeIfPresent(StringUnit.self, forKey: .stringUnit) {
            self = .stringUnit(stringUnit)
        } else if let variations = try container.decodeIfPresent(Variations.self, forKey: .variations) {
            self = .variations(variations)
        } else {
            throw DecodingError.typeMismatch(Self.self, .init(
                codingPath: [CodingKeys.stringUnit, CodingKeys.variations],
                debugDescription: "Failed to decode XCStrings.Strings.Localization."
            ))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .stringUnit(stringUnit):
            try container.encode(stringUnit, forKey: .stringUnit)
        case let .variations(variations):
            try container.encode(variations, forKey: .variations)
        }
    }
}
