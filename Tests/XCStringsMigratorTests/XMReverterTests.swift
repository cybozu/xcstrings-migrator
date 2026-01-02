import Foundation
import Testing

@testable import XCStringsMigrator

@Suite(.serialized)
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
                "%lld item(s)": Strings(localizations: [
                    "en": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "%lld item")),
                        "one": PluralVariation(stringUnit: .init(value: "%lld item")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld items")),
                    ])),
                    "ja": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "%lld個")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld個")),
                    ]))
                ])
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
                    "en": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "en_value_zero")),
                        "one": PluralVariation(stringUnit: .init(value: "en_value_one")),
                        "other": PluralVariation(stringUnit: .init(value: "en_value_other")),
                    ])),
                    "ja": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "ja_value_zero")),
                        "other": PluralVariation(stringUnit: .init(value: "ja_value_other")),
                    ])),
                ]),
            ],
            version: "1.0"
        )
        let (actualStrings, actualStringsDict) = sut.convertToStringsData(from: input)
        let expectStrings = [
            StringsData(
                tableName: "Localizable",
                language: "en",
                values: [
                    "key1": .simple("en_value_1"),
                    "key2": .simple("en_value_2"),
                ]
            ),
            StringsData(
                tableName: "Localizable",
                language: "ja",
                values: [
                    "key1": .simple("ja_value_1"),
                    "key2": .simple("ja_value_2"),
                ]
            ),
        ]
        let expectStringsDict = [
            StringsData(
                tableName: "Localizable",
                language: "en",
                values: [
                    "key3": .plural([
                        "zero": "en_value_zero",
                        "one": "en_value_one",
                        "other": "en_value_other",
                    ]),
                ]
            ),
            StringsData(
                tableName: "Localizable",
                language: "ja",
                values: [
                    "key3": .plural([
                        "zero": "ja_value_zero",
                        "other": "ja_value_other",
                    ]),
                ]
            ),
        ]
        #expect(actualStrings.sorted(by: { $0.language < $1.language }) == expectStrings)
        #expect(actualStringsDict.sorted(by: { $0.language < $1.language }) == expectStringsDict)
    }

    @Test("If exporting file fails, an error is thrown.")
    func exportStringsFile_negative() throws {
        var sut = XMReverter(path: "", outputPath: "")
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        sut.writeData = { _, _ in
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
        var writeDataCount = Int.zero
        sut.writeData = { _, url in
            #expect(url.path() == "output/test.lproj/Localizable.strings")
            writeDataCount += 1
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
        #expect(standardOutputs == ["Succeeded to export strings file."])
        #expect(writeDataCount == 1)
    }

    @Test("If exporting file fails, an error is thrown.")
    func exportStringsDictFile_negative() throws {
        var sut = XMReverter(path: "", outputPath: "")
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        sut.writeData = { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }
        let input = StringsData(tableName: "Localizable", language: "test", values: [:])
        #expect(throws: XMError.failedToExportStringsFile) {
            try sut.exportStringsDictFile(input)
        }
        #expect(standardOutputs.isEmpty)
    }

    @Test("If StringsData is valid, file is successfully exported.")
    func exportStringsDictFile_positive() throws {
        var sut = XMReverter(path: "", outputPath: "output")
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        var writeDataCount = Int.zero
        sut.writeData = { text, url in
            #expect(url.path() == "output/test.lproj/Localizable.stringsdict")
            writeDataCount += 1
        }
        let input = StringsData(
            tableName: "Localizable",
            language: "test",
            values: [
                "%lld item(s)": .plural([
                    "zero": "%lld item",
                    "one": "%lld item",
                    "other": "%lld items",
                ]),
            ]
        )
        try sut.exportStringsDictFile(input)
        #expect(standardOutputs == ["Succeeded to export stringsdict file."])
        #expect(writeDataCount == 1)
    }
}
