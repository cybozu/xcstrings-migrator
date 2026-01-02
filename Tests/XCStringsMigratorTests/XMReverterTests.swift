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
                "\"Hello %@\"": .init(localizations: [
                    "en": .stringUnit(.init(value: "\"Hello %@\"")),
                    "ja": .stringUnit(.init(value: "「こんにちは%@」")),
                ]),
                "Count = %lld": .init(localizations: [
                    "en": .stringUnit(.init(value: "Count = %lld")),
                    "ja": .stringUnit(.init(value: "カウント＝%lld")),
                ]),
                "language": .init(localizations: [
                    "en": .stringUnit(.init(value: "English")),
                    "ja": .stringUnit(.init(value: "日本語")),
                ]),
                "path": .init(localizations: [
                    "en": .stringUnit(.init(value: "/")),
                    "ja": .stringUnit(.init(value: "/")),
                ]),
                "%lld item(s)": .init(localizations: [
                    "en": .variations(.init(plural: [
                        "zero": .init(stringUnit: .init(value: "%lld item")),
                        "one": .init(stringUnit: .init(value: "%lld item")),
                        "other": .init(stringUnit: .init(value: "%lld items")),
                    ])),
                    "ja": .variations(.init(plural: [
                        "zero": .init(stringUnit: .init(value: "%lld個")),
                        "other": .init(stringUnit: .init(value: "%lld個")),
                    ])),
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
                "key1": .init(localizations: [
                    "en": .stringUnit(.init(value: "en_value_1")),
                    "ja": .stringUnit(.init(value: "ja_value_1")),
                ]),
                "key2": .init(localizations: [
                    "en": .stringUnit(.init(value: "en_value_2")),
                    "ja": .stringUnit(.init(value: "ja_value_2")),
                ]),
                "key3": .init(localizations: [
                    "en": .variations(.init(plural: [
                        "zero": .init(stringUnit: .init(value: "en_value_zero")),
                        "one": .init(stringUnit: .init(value: "en_value_one")),
                        "other": .init(stringUnit: .init(value: "en_value_other")),
                    ])),
                    "ja": .variations(.init(plural: [
                        "zero": .init(stringUnit: .init(value: "ja_value_zero")),
                        "other": .init(stringUnit: .init(value: "ja_value_other")),
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
                items: [
                    .init(key: "key1", value: .singular("en_value_1")),
                    .init(key: "key2", value: .singular("en_value_2")),
                ]
            ),
            StringsData(
                tableName: "Localizable",
                language: "ja",
                items: [
                    .init(key: "key1", value: .singular("ja_value_1")),
                    .init(key: "key2", value: .singular("ja_value_2")),
                ]
            ),
        ]
        let expectStringsDict = [
            StringsData(
                tableName: "Localizable",
                language: "en",
                items: [
                    .init(key: "key3", value: .plural([
                        .init(rule: .one, value: "en_value_one"),
                        .init(rule: .other, value: "en_value_other"),
                        .init(rule: .zero, value: "en_value_zero"),
                    ])),
                ]
            ),
            StringsData(
                tableName: "Localizable",
                language: "ja",
                items: [
                    .init(key: "key3", value: .plural([
                        .init(rule: .other, value: "ja_value_other"),
                        .init(rule: .zero, value: "ja_value_zero"),
                    ])),
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
        let input = StringsData(tableName: "Localizable", language: "test", items: [])
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
            items: [
                .init(key: "\"Hello %@\"", value: .singular("\"Hello %@\"")),
                .init(key: "Count = %lld", value: .singular("Count = %lld")),
                .init(key: "key", value: .singular("value")),
                .init(key: "path", value: .singular("/")),
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
        let input = StringsData(tableName: "Localizable", language: "test", items: [])
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
            items: [
                .init(key: "%lld item(s)", value: .plural([
                    .init(rule: .one, value: "%lld item"),
                    .init(rule: .other, value: "%lld items"),
                    .init(rule: .zero, value: "%lld item"),
                ])),
            ]
        )
        try sut.exportStringsDictFile(input)
        #expect(standardOutputs == ["Succeeded to export stringsdict file."])
        #expect(writeDataCount == 1)
    }
}
