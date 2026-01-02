import Foundation
import Testing

@testable import XCStringsMigrator

struct XMReverterTests {
    @Test("If path extension is not xcstrings, error is thrown.")
    func extractXCStrings_negative_1() throws {
        let url = try #require(Bundle.module.resourceURL).appending(path: "dummy")
        let sut = XMReverter(path: url.path(), outputPath: "")
        #expect(throws: XMError.xcstringsFileNotFound) {
            try sut.extractXCStrings()
        }
    }

    @Test("If path extension is xcstrings but file does not exist, error is thrown.")
    func extractXCStrings_negative_2() throws {
        let url = try #require(Bundle.module.resourceURL).appending(path: "not-exist.xcstrings")
        let sut = XMReverter(path: url.path(), outputPath: "")
        #expect(throws: XMError.xcstringsFileNotFound) {
            try sut.extractXCStrings()
        }
    }

    @Test("If path extension is xcstrings and file exists but is broken, error is thrown.")
    func extractXCStrings_negative_3() throws {
        let url = try #require(Bundle.module.url(forResource: "Broken", withExtension: "xcstrings", subdirectory: "Reverter"))
        let sut = XMReverter(path: url.path(), outputPath: "")
        #expect(throws: XMError.xcstringsFileIsBroken) {
            try sut.extractXCStrings()
        }
    }

    @Test("If path extension is xcstrings and file exists, XCStrings is returned.")
    func extractXCStrings_positive() throws {
        let url = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings", subdirectory: "Reverter"))
        let sut = XMReverter(path: url.path(), outputPath: "")
        let actual = try sut.extractXCStrings()
        let expect = XCStrings(
            sourceLanguage: "en",
            strings: [
                "\"Hello %@\"": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "\"Hello %@\"")),
                    "ja": Localization(stringUnit: .init(value: "「こんにちは%@」")),
                ]),
                "Count = %lld": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "Count = %lld")),
                    "ja": Localization(stringUnit: .init(value: "カウント＝%lld")),
                ]),
                "language": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "English")),
                    "ja": Localization(stringUnit: .init(value: "日本語")),
                ]),
                "path": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "/")),
                    "ja": Localization(stringUnit: .init(value: "/")),
                ]),
            ],
            version: "1.0"
        )
        #expect(actual == expect)
    }

    @Test("XCStrings is converted to StringsData array.")
    func convertToStringsData_positive() throws {
        let sut = XMReverter(path: "", outputPath: "")
        let input = XCStrings(
            sourceLanguage: "test",
            strings: [
                "key1": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "en_value_1")),
                    "ja": Localization(stringUnit: .init(value: "ja_value_1")),
                ]),
                "key2": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "en_value_2")),
                    "ja": Localization(stringUnit: .init(value: "ja_value_2")),
                ]),
                "key3": Strings(localizations: [
                    "en": Localization(stringUnit: .init(value: "en_value_3")),
                    "ja": Localization(stringUnit: .init(value: "ja_value_3")),
                ]),
            ],
            version: "1.0"
        )
        let (actualStrings, actualStringsDict) = sut.convertToStringsData(from: input)
        let expect = [
            StringsData(
                tableName: "Localizable",
                language: "en",
                values: [
                    "key1": .simple("en_value_1"),
                    "key2": .simple("en_value_2"),
                    "key3": .simple("en_value_3"),
                ]
            ),
            StringsData(
                tableName: "Localizable",
                language: "ja",
                values: [
                    "key1": .simple("ja_value_1"),
                    "key2": .simple("ja_value_2"),
                    "key3": .simple("ja_value_3"),
                ]
            ),
        ]
        #expect(actualStrings.sorted(by: { $0.language < $1.language }) == expect)
        #expect(actualStringsDict.isEmpty)
    }

    @Test("If exporting file fails, an error is thrown.")
    func exportStringsFile_negative() throws {
        var sut = XMReverter(path: "", outputPath: "")
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        sut.writeString = { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }
        let input = StringsData(tableName: "Localizable", language: "test", values: [:])
        #expect(throws: XMError.failedToExportStringsFile) {
            try sut.exportStringsFile(input)
        }
        #expect(standardOutputs.isEmpty)
    }

    @Test("If StringsData is valid, file is successfully exported.")
    func exportStringsFile_positive() throws {
        var sut = XMReverter(path: "", outputPath: "output")
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        var writeStrings = [String]()
        sut.writeString = { text, url in
            #expect(url.path() == "output/test.lproj/Localizable.strings")
            writeStrings.append(text)
        }

        let input = StringsData(
            tableName: "Localizable",
            language: "test",
            values: [
                "\"Hello %@\"": .simple("\"Hello %@\""),
                "Count = %lld": .simple("Count = %lld"),
                "key": .simple("value"),
                "path": .simple("/"),
            ]
        )
        try sut.exportStringsFile(input)
        let details = #"""
            "\"Hello %@\"" = "\"Hello %@\"";
            "Count = %lld" = "Count = %lld";
            "key" = "value";
            "path" = "/";
            """#
        #expect(standardOutputs == ["Succeeded to export strings file."])
        #expect(writeStrings == [details])
    }
}
