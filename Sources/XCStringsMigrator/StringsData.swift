enum LocalizationValue: Equatable {
    case simple(String)
    case plural([String: String])
}

struct StringsData: Equatable {
    var tableName: String
    var language: String
    var values: [String: LocalizationValue]
}
