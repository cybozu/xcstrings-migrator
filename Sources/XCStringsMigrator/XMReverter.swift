import Foundation

public struct XMReverter {
    private var path: String
    private var outputPath: String
    var standardOutput: (Any...) -> Void
    var createDirectory: (URL) throws -> Void
    var writeString: (String, URL) throws -> Void

    public init(path: String, outputPath: String) {
        self.path = path
        self.outputPath = outputPath
        self.standardOutput = {
            Swift.print($0.map({ "\($0)" }).joined(separator: " "))
        }
        self.createDirectory = {
            try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
        }
        self.writeString = {
            try $0.write(to: $1, atomically: false, encoding: .utf8)
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
        var stringsArray: [StringsData] = []
        var stringsDictArray: [StringsData] = []
        
        xcstrings.strings.forEach { stringKey, strings in
            strings.localizations.forEach { language, localization in
                // Check if this is a plural variation or simple string
                if let variations = localization.variations,
                   let pluralVariations = variations.plural {
                    // Handle plural - goes to stringsdict
                    let pluralValues = pluralVariations.mapValues { $0.stringUnit.value }
                    if let index = stringsDictArray.firstIndex(where: { $0.language == language }) {
                        stringsDictArray[index].values[stringKey] = .plural(pluralValues)
                    } else {
                        stringsDictArray.append(StringsData(
                            tableName: "Localizable",
                            language: language,
                            values: [stringKey: .plural(pluralValues)]
                        ))
                    }
                } else if let stringUnit = localization.stringUnit {
                    // Handle simple string - goes to strings
                    if let index = stringsArray.firstIndex(where: { $0.language == language }) {
                        stringsArray[index].values[stringKey] = .simple(stringUnit.value)
                    } else {
                        stringsArray.append(StringsData(
                            tableName: "Localizable",
                            language: language,
                            values: [stringKey: .simple(stringUnit.value)]
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
            let text = stringsData.values
                .sorted(by: { $0.key < $1.key })
                .compactMap { key, value -> String? in
                    guard case .simple(let stringValue) = value else { return nil }
                    return "\(key.debugDescription) = \(stringValue.debugDescription);"
                }
                .joined(separator: "\n")
            try writeString(text, outputFileURL)
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
            
            // Build the plist dictionary
            var plistDict: [String: [String: Any]] = [:]
            
            for (key, value) in stringsData.values.sorted(by: { $0.key < $1.key }) {
                guard case .plural(let pluralRules) = value else { continue }
                
                // Create the variable name (use "format" as default)
                let variableName = "format"
                
                // Build the variable dictionary
                var variableDict: [String: Any] = [
                    "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                    "NSStringFormatValueTypeKey": "li"
                ]
                
                // Add plural rules
                for (pluralKey, pluralValue) in pluralRules {
                    variableDict[pluralKey] = pluralValue
                }
                
                // Build the top-level dictionary for this key
                plistDict[key] = [
                    "NSStringLocalizedFormatKey": "%#@\(variableName)@",
                    variableName: variableDict
                ]
            }
            
            // Convert to XML plist
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: plistDict,
                format: .xml,
                options: 0
            )
            
            try plistData.write(to: outputFileURL)
            standardOutput("Succeeded to export stringsdict file.")
        } catch {
            throw XMError.failedToExportStringsFile
        }
    }
}
