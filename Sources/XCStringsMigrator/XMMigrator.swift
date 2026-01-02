import Foundation

public struct XMMigrator {
    private var sourceLanguage: String
    private var paths: [String]
    private var outputPath: String
    private var verbose: Bool
    var standardOutput: (Any...) -> Void
    var writeData: (Data, URL) throws -> Void

    public init(
        sourceLanguage: String,
        paths: [String],
        outputPath: String,
        verbose: Bool
    ) {
        self.sourceLanguage = sourceLanguage
        self.paths = paths
        self.outputPath = outputPath
        self.verbose = verbose
        self.standardOutput = {
            Swift.print($0.map({ "\($0)" }).joined(separator: " "))
        }
        self.writeData = {
            try $0.write(to: $1)
        }
    }

    public func run() throws {
        let array = try extractStringsData()
        let dict = classifyStringsData(with: array)
        try dict.forEach { key, value in
            let xcstrings = convertToXCStrings(from: value)
            try exportXCStringsFile(name: key, xcstrings)
        }
        standardOutput("Completed.")
    }

    func extractSingularValue(from url: URL) -> [String: String]? {
        let decoder = PropertyListDecoder()
        var format = PropertyListSerialization.PropertyListFormat.openStep
        guard let data = try? Data(contentsOf: url),
              let dictionary = try? decoder.decode([String: String].self, from: data, format: &format) else {
            return nil
        }
        return dictionary
    }

    func extractVariableName(from formatKey: String) -> String? {
        let pattern = "%#@([^@]+)@"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: formatKey, range: NSRange(formatKey.startIndex..., in: formatKey)),
              let range = Range(match.range(at: 1), in: formatKey) else {
            return nil
        }
        return String(formatKey[range])
    }

    func extractPluralValue(from url: URL) -> [String: [String: String]]? {
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: &format),
              let dictionary = plist as? [String: [String: Any]] else {
            return nil
        }
        return dictionary.compactMapValues { topLevelDict -> [String: String]? in
            guard let formatKey = topLevelDict["NSStringLocalizedFormatKey"] as? String,
                  let variableName = extractVariableName(from: formatKey),
                  let variableDict = topLevelDict[variableName] as? [String: Any],
                  let specType = variableDict["NSStringFormatSpecTypeKey"] as? String,
                  specType == "NSStringPluralRuleType" else {
                return nil
            }
            let pluralRules = ["zero", "one", "two", "few", "many", "other"].reduce(into: [String: String]()) { partialResult, key in
                guard let value = variableDict[key] as? String else { return }
                partialResult[key] = value
            }
            return pluralRules.isEmpty ? nil : pluralRules
        }
    }

    func extractStringsData() throws -> [StringsData] {
        let fileManager = FileManager.default
        let stringsFiles = paths
            .map { URL(filePath: $0) }
            .filter { url in
                url.pathExtension == "lproj" && fileManager.fileExists(atPath: url.path())
            }
            .flatMap { url -> [StringsFile] in
                guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path()) else {
                    return []
                }
                let language = url.deletingPathExtension().lastPathComponent
                return contents
                    .map { url.appending(component: $0) }
                    .compactMap { StringsFile(language: language, url: $0) }
            }
        guard !stringsFiles.isEmpty else {
            throw XMError.stringsFilesNotFound
        }
        return stringsFiles.compactMap { stringsFile -> StringsData? in
            switch stringsFile.type {
            case .strings:
                guard let singularValues = extractSingularValue(from: stringsFile.url) else { return nil }
                let items = singularValues.map {
                    StringsData.Item(key: $0.key, value: .singular($0.value))
                }.sorted { $0.key < $1.key }
                return StringsData(tableName: stringsFile.tableName, language: stringsFile.language, items: items)
            case .stringsdict:
                guard let pluralValues = extractPluralValue(from: stringsFile.url) else { return nil }
                let items = pluralValues.map {
                    StringsData.Item(
                        key: $0.key,
                        value: .plural($0.value
                            .compactMap {
                                guard let rule = StringsData.Item.Value.Plural.Rule(rawValue: $0.key) else { return nil }
                                return StringsData.Item.Value.Plural(rule: rule, value: $0.value)
                            }
                            .sorted { $0.rule.rawValue < $1.rule.rawValue }
                        )
                    )
                }.sorted { $0.key < $1.key }
                return StringsData(tableName: stringsFile.tableName, language: stringsFile.language, items: items)
            }
        }
    }

    func classifyStringsData(with array: [StringsData]) -> [String: [StringsData]] {
        array.reduce(into: [String: [StringsData]]()) { partialResult, stringsData in
            let key = stringsData.tableName
            if partialResult.keys.contains(key) {
                partialResult[key]?.append(stringsData)
            } else {
                partialResult[key] = [stringsData]
            }
        }
    }

    func convertToXCStrings(from array: [StringsData]) -> XCStrings {
        let strings = array.reduce(into: [String: XCStrings.Strings]()) { partialResult, stringsData in
            stringsData.items.forEach { item in
                let localization: XCStrings.Strings.Localization = switch item.value {
                case let .singular(value):
                    XCStrings.Strings.Localization.stringUnit(.init(value: value))
                case let .plural(value):
                    XCStrings.Strings.Localization.variations(.init(
                        plural: value.reduce(into: [String: Variations.PluralVariation]()) { result, plural in
                            result[plural.rule.rawValue] = Variations.PluralVariation(stringUnit: .init(value: plural.value))
                        }
                    ))
                }
                if partialResult.keys.contains(item.key) {
                    partialResult[item.key]?.localizations[stringsData.language] = localization
                } else {
                    partialResult[item.key] = .init(localizations: [stringsData.language: localization])
                }
            }
        }
        return XCStrings(
            sourceLanguage: sourceLanguage,
            strings: strings,
            version: "1.0"
        )
    }

    func exportXCStringsFile(name: String, _ xcstrings: XCStrings) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes,
            ]
            let data = try encoder.encode(xcstrings)
            if verbose, let jsonString = String(data: data, encoding: .utf8) {
                standardOutput(jsonString)
            }
            let outputURL = URL(filePath: outputPath)
                .appending(path: name)
                .appendingPathExtension("xcstrings")
            try writeData(data, outputURL)
            standardOutput("Succeeded to export xcstrings files.")
        } catch {
            throw XMError.failedToExportXCStringsFile
        }
    }
}
