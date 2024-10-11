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
        let array = convertToStringsData(from: xcstrings)
        try array.forEach { stringsData in
            try exportStringsFile(stringsData)
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

    func convertToStringsData(from xcstrings: XCStrings) -> [StringsData] {
        xcstrings.strings.reduce(into: [StringsData]()) { partialResult, item in
            item.value.localizations.forEach { language, localization in
                if let index = partialResult.firstIndex(where: { $0.language == language }) {
                    partialResult[index].values[item.key] = localization.stringUnit.value
                } else {
                    partialResult.append(StringsData(
                        tableName: "Localizable",
                        language: language,
                        values: [item.key : localization.stringUnit.value]
                    ))
                }
            }
        }
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
                .map { "\($0.key.debugDescription) = \($0.value.debugDescription);" }
                .joined(separator: "\n")
            try writeString(text, outputFileURL)
            standardOutput("Succeeded to export strings file.")
        } catch {
            throw XMError.failedToExportStringsFile
        }
    }
}
