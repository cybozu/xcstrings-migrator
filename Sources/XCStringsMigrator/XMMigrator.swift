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

    func extractKeyValue(from url: URL) -> [String: String]? {
        let decoder = PropertyListDecoder()
        var format = PropertyListSerialization.PropertyListFormat.openStep
        guard let data = try? Data(contentsOf: url),
              let dictionary = try? decoder.decode([String : String].self, from: data, format: &format) else {
            return nil
        }
        return dictionary
    }
    
    func extractStringsDictValue(from url: URL) -> [String: [String: String]]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: [String: Any]] else {
            return nil
        }
        
        return dictionary.compactMapValues { topLevelDict -> [String: String]? in
            // Extract the format key (e.g., "%#@format@")
            guard let formatKey = topLevelDict["NSStringLocalizedFormatKey"] as? String else {
                return nil
            }
            
            // Extract variable name from formatKey (e.g., "%#@format@" -> "format")
            let variableName = extractVariableName(from: formatKey)
            guard !variableName.isEmpty else { return nil }
            
            // Get the variable dictionary
            guard let variableDict = topLevelDict[variableName] as? [String: Any],
                  let specType = variableDict["NSStringFormatSpecTypeKey"] as? String,
                  specType == "NSStringPluralRuleType" else {
                return nil
            }
            
            // Extract plural variations (zero, one, two, few, many, other)
            var pluralRules: [String: String] = [:]
            for key in ["zero", "one", "two", "few", "many", "other"] {
                if let value = variableDict[key] as? String {
                    pluralRules[key] = value
                }
            }
            
            return pluralRules.isEmpty ? nil : pluralRules
        }
    }
    
    private func extractVariableName(from formatKey: String) -> String {
        // Extract variable from "%#@format@" -> "format"
        let pattern = "%#@([^@]+)@"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: formatKey, range: NSRange(formatKey.startIndex..., in: formatKey)),
              let range = Range(match.range(at: 1), in: formatKey) else {
            return ""
        }
        return String(formatKey[range])
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
                    .filter { $0.pathExtension == "strings" || $0.pathExtension == "stringsdict" }
                    .map { StringsFile(language: language, url: $0) }
            }
        guard !stringsFiles.isEmpty else {
            throw XMError.stringsFilesNotFound
        }
        return stringsFiles.compactMap { stringsFile in
            let tableName = stringsFile.url.deletingPathExtension().lastPathComponent
            let isStringsDict = stringsFile.url.pathExtension == "stringsdict"
            
            if isStringsDict {
                guard let pluralValues = extractStringsDictValue(from: stringsFile.url) else { return nil }
                let values = pluralValues.mapValues { LocalizationValue.plural($0) }
                return StringsData(tableName: tableName, language: stringsFile.language, values: values)
            } else {
                guard let simpleValues = extractKeyValue(from: stringsFile.url) else { return nil }
                let values = simpleValues.mapValues { LocalizationValue.simple($0) }
                return StringsData(tableName: tableName, language: stringsFile.language, values: values)
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
        let strings = array.reduce(into: [String: Strings]()) { partialResult, stringsData in
            stringsData.values.forEach { stringKey, localizationValue in
                let localization: Localization
                
                switch localizationValue {
                case .simple(let value):
                    localization = Localization(
                        stringUnit: StringUnit(value: value),
                        variations: nil
                    )
                
                case .plural(let pluralRules):
                    let pluralVariations = pluralRules.mapValues { value in
                        PluralVariation(stringUnit: StringUnit(value: value))
                    }
                    localization = Localization(
                        stringUnit: nil,
                        variations: Variations(plural: pluralVariations)
                    )
                }
                
                if partialResult.keys.contains(stringKey) {
                    partialResult[stringKey]?.localizations[stringsData.language] = localization
                } else {
                    partialResult[stringKey] = Strings(localizations: [stringsData.language: localization])
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
