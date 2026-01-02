import Foundation

public struct XMReverter {
    private var path: String
    private var outputPath: String
    var standardOutput: (Any...) -> Void
    var createDirectory: (URL) throws -> Void
    var writeData: (Data, URL) throws -> Void

    public init(path: String, outputPath: String) {
        self.path = path
        self.outputPath = outputPath
        self.standardOutput = {
            Swift.print($0.map({ "\($0)" }).joined(separator: " "))
        }
        self.createDirectory = {
            try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
        }
        self.writeData = {
            try $0.write(to: $1)
        }
    }

    public func run() throws {
        let xcstrings = try extractXCStrings()
        let (stringsArray, stringsDictArray) = convertToStringsData(from: xcstrings)
        try stringsArray.forEach { stringsData in
            try exportStringsFile(stringsData)
        }
        try stringsDictArray.forEach { stringsData in
            try exportStringsDictFile(stringsData)
        }
        standardOutput("Completed.")
    }

    func extractXCStrings() throws -> XCStrings {
        let fileManager = FileManager.default
        let url = URL(filePath: path)
        guard url.pathExtension == "xcstrings", fileManager.fileExists(atPath: url.path()) else {
            throw XMError.xcstringsFileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(XCStrings.self, from: data)
        } catch {
            throw XMError.xcstringsFileIsBroken
        }
    }

    func convertToStringsData(from xcstrings: XCStrings) -> (strings: [StringsData], stringsdict: [StringsData]) {
        var stringsArray = [StringsData]()
        var stringsDictArray = [StringsData]()
        xcstrings.strings.forEach { stringKey, strings in
            strings.localizations.forEach { language, localization in
                switch localization {
                case let .stringUnit(stringUnit):
                    if let index = stringsArray.firstIndex(where: { $0.language == language }) {
                        stringsArray[index].items.append(.init(key: stringKey, value: .singular(stringUnit.value)))
                    } else {
                        stringsArray.append(StringsData(
                            tableName: "Localizable",
                            language: language,
                            items: [.init(key: stringKey, value: .singular(stringUnit.value))]
                        ))
                    }
                case let .variations(variations):
                    let plurals: [StringsData.Item.Value.Plural] = variations.plural
                        .compactMap {
                            guard let rule = StringsData.Item.Value.Plural.Rule(rawValue: $0.key) else { return nil }
                            return StringsData.Item.Value.Plural(rule: rule, value: $0.value.stringUnit.value)
                        }
                        .sorted { $0.rule.rawValue < $1.rule.rawValue }
                    if let index = stringsDictArray.firstIndex(where: { $0.language == language }) {
                        stringsDictArray[index].items.append(.init(key: stringKey, value: .plural(plurals)))
                    } else {
                        stringsDictArray.append(StringsData(
                            tableName: "Localizable",
                            language: language,
                            items: [.init(key: stringKey, value: .plural(plurals))]
                        ))
                    }
                }
            }
        }
        return (stringsArray, stringsDictArray)
    }

    func exportStringsFile(_ stringsData: StringsData) throws {
        do {
            let outputFolderURL = URL(filePath: outputPath)
                .appending(path: stringsData.language)
                .appendingPathExtension("lproj")
            try createDirectory(outputFolderURL)
            let outputFileURL = outputFolderURL
                .appending(path: stringsData.tableName)
                .appendingPathExtension("strings")
            let data = stringsData.items
                .sorted(by: { $0.key < $1.key })
                .compactMap { item -> String? in
                    guard case let .singular(stringValue) = item.value else { return nil }
                    return "\(item.key.debugDescription) = \(stringValue.debugDescription);"
                }
                .joined(separator: "\n")
                .data(using: .utf8)!
            try writeData(data, outputFileURL)
            standardOutput("Succeeded to export strings file.")
        } catch {
            throw XMError.failedToExportStringsFile
        }
    }
    
    func exportStringsDictFile(_ stringsData: StringsData) throws {
        do {
            let outputFolderURL = URL(filePath: outputPath)
                .appending(path: stringsData.language)
                .appendingPathExtension("lproj")
            try createDirectory(outputFolderURL)
            let outputFileURL = outputFolderURL
                .appending(path: stringsData.tableName)
                .appendingPathExtension("stringsdict")
            let plistDict = stringsData.items
                .sorted(by: { $0.key < $1.key })
                .compactMap { item -> (key: String, dict: [String: String])? in
                    guard case let .plural(plurals) = item.value else { return nil }
                    var dict: [String: String] = [
                        "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                        "NSStringFormatValueTypeKey": "li",
                    ]
                    plurals.forEach { plural in
                        dict[plural.rule.rawValue] = plural.value
                    }
                    return (item.key, dict)
                }
                .reduce(into: [String: [String: Any]]()) { partialResult, element in
                    partialResult[element.key] = [
                        "NSStringLocalizedFormatKey": "%#@format@",
                        "format": element.dict
                    ]
                }
            let data = try PropertyListSerialization.data(
                fromPropertyList: plistDict,
                format: .xml,
                options: 0
            )
            try writeData(data, outputFileURL)
            standardOutput("Succeeded to export stringsdict file.")
        } catch {
            throw XMError.failedToExportStringsDictFile
        }
    }
}
