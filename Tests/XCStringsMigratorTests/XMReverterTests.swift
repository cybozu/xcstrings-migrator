import XCTest

@testable import XCStringsMigrator

final class XMReverterTests: XCTestCase {
    func test_extractXCStrings() throws {
        try XCTContext.runActivity(named: "If path extension is not xcstrings, error is thrown.") { _ in
            let url = try XCTUnwrap(Bundle.module.resourceURL).appending(path: "dummy")
            let sut = XMReverter(path: url.path(), outputPath: "")
            XCTAssertThrowsError(try sut.extractXCStrings()) { error in
                XCTAssertEqual(error as? XMError, XMError.xcstringsFileNotFound)
            }
        }
        try XCTContext.runActivity(named: "If path extension is xcstrings but file does not exist, error is thrown.") { _ in
            let url = try XCTUnwrap(Bundle.module.resourceURL).appending(path: "not-exist.xcstrings")
            let sut = XMReverter(path: url.path(), outputPath: "")
            XCTAssertThrowsError(try sut.extractXCStrings()) { error in
                XCTAssertEqual(error as? XMError, XMError.xcstringsFileNotFound)
            }
        }
        try XCTContext.runActivity(named: "If path extension is xcstrings and file exists but is broken, error is thrown.") { _ in
            let url = try XCTUnwrap(Bundle.module.url(forResource: "Broken", withExtension: "xcstrings", subdirectory: "Reverter"))
            let sut = XMReverter(path: url.path(), outputPath: "")
            XCTAssertThrowsError(try sut.extractXCStrings()) { error in
                XCTAssertEqual(error as? XMError, XMError.xcstringsFileIsBroken)
            }
        }
        try XCTContext.runActivity(named: "") { _ in
            let url = try XCTUnwrap(Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings", subdirectory: "Reverter"))
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
            XCTAssertEqual(actual, expect)
        }
    }

    func test_convertToStringsData() {
        XCTContext.runActivity(named: "XCStrings is converted to StringsData array.") { _ in
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
            XCTAssertEqual(actualStrings.sorted(by: { $0.language < $1.language }), expect)
            XCTAssertTrue(actualStringsDict.isEmpty)
        }
    }

    func test_exportStringsFile() throws {
        try XCTContext.runActivity(named: "If StringsData is valid, file is successfully exported.") { _ in
            var sut = XMReverter(path: "", outputPath: "output")
            var standardOutputs = [String]()
            sut.standardOutput = { items in
                standardOutputs.append(contentsOf: items.map({ "\($0)" }))
            }
            var writeStrings = [String]()
            sut.writeString = { text, url in
                XCTAssertEqual(url.path(), "output/test.lproj/Localizable.strings")
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
            XCTAssertEqual(standardOutputs, ["Succeeded to export strings file."])
            XCTAssertEqual(writeStrings, [details])
        }
        try XCTContext.runActivity(named: "If exporting file fails, an error is thrown.") { _ in
            var sut = XMReverter(path: "", outputPath: "")
            var standardOutputs = [String]()
            sut.standardOutput = { items in
                standardOutputs.append(contentsOf: items.map({ "\($0)" }))
            }
            sut.writeString = { _, _ in
                throw CocoaError(.fileWriteUnknown)
            }
            let input = StringsData(tableName: "Localizable", language: "test", values: [:])
            XCTAssertThrowsError(try sut.exportStringsFile(input)) { error in
                XCTAssertEqual(error as? XMError, XMError.failedToExportStringsFile)
            }
            XCTAssertTrue(standardOutputs.isEmpty)
        }
    }
}
