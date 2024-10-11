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
    var stringUnit: StringUnit
}

struct StringUnit: Codable, Equatable {
    var state: String
    var value: String

    init(state: String = "translated", value: String) {
        self.state = state
        self.value = value
    }
}
