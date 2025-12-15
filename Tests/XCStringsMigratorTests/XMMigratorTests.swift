import XCTest

@testable import XCStringsMigrator

final class XMMigratorTests: XCTestCase {
    func test_extractKeyValue() throws {
        try XCTContext.runActivity(named: "If URL is invalid, nil will be returned.") { _ in
            let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
            let url = try XCTUnwrap(Bundle.module.resourceURL).appending(path: "not-exist.strings")
            let actual = sut.extractKeyValue(from: url)
            XCTAssertNil(actual)
        }
        try XCTContext.runActivity(named: "If strings file is valid, dictionary will be returned.") { _ in
            let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
            let url = try XCTUnwrap(Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: "Migrator"))
            let actual = sut.extractKeyValue(from: url)
            let expect = [
                "\"Hello %@\"": "\"Hello %@\"",
                "Count = %lld": "Count = %lld",
                "key": "value",
                "path": "/",
            ]
            XCTAssertEqual(actual, expect)
        }
    }

    func test_extractStringsData() throws {
        try XCTContext.runActivity(named: "If paths is empty, error is thrown.") { _ in
            let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
            XCTAssertThrowsError(try sut.extractStringsData()) { error in
                XCTAssertEqual(error as? XMError, XMError.stringsFilesNotFound)
            }
        }
        try XCTContext.runActivity(named: "If path extension is not lproj, error is thrown.") { _ in
            let url = try XCTUnwrap(Bundle.module.resourceURL).appending(path: "dummy")
            let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
            XCTAssertThrowsError(try sut.extractStringsData()) { error in
                XCTAssertEqual(error as? XMError, XMError.stringsFilesNotFound)
            }
        }
        try XCTContext.runActivity(named: "If path extension is lproj but file does not exist, error is thrown.") { _ in
            let url = try XCTUnwrap(Bundle.module.resourceURL).appending(path: "not-exist.lproj")
            let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
            XCTAssertThrowsError(try sut.extractStringsData()) { error in
                XCTAssertEqual(error as? XMError, XMError.stringsFilesNotFound)
            }
        }
        try XCTContext.runActivity(named: "If path extension is lproj and file exists but contains no strings files, error is thrown.") { _ in
            let url = try XCTUnwrap(Bundle.module.url(forResource: "empty", withExtension: "lproj", subdirectory: "Migrator"))
            let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
            XCTAssertThrowsError(try sut.extractStringsData()) { error in
                XCTAssertEqual(error as? XMError, XMError.stringsFilesNotFound)
            }
        }
        try XCTContext.runActivity(named: "If path extension is lproj and file exists and contains some strings files, array with elements is returned.") { _ in
            let url = try XCTUnwrap(Bundle.module.url(forResource: "full", withExtension: "lproj", subdirectory: "Migrator"))
            let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
            let actual = try sut.extractStringsData()
            let expect = [
                StringsData(
                    tableName: "Localizable",
                    language: "full",
                    values: [
                        "\"Hello %@\"": .simple("\"Hello %@\""),
                        "Count = %lld": .simple("Count = %lld"),
                        "key": .simple("value"),
                        "path": .simple("/"),
                    ]
                )
            ]
            XCTAssertEqual(actual, expect)
        }
    }

    func test_classifyStringsData() throws {
        XCTContext.runActivity(named: "StringsData array is classified by table name.") { _ in
            let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
            let input: [StringsData] = [
                StringsData(tableName: "Module1", language: "en", values: [:]),
                StringsData(tableName: "Module1", language: "ja", values: [:]),
                StringsData(tableName: "Module2", language: "en", values: [:]),
                StringsData(tableName: "Module2", language: "ja", values: [:]),
            ]
            let actual = sut.classifyStringsData(with: input)
            let expect = [
                "Module1": [
                    StringsData(tableName: "Module1", language: "en", values: [:]),
                    StringsData(tableName: "Module1", language: "ja", values: [:]),
                ],
                "Module2": [
                    StringsData(tableName: "Module2", language: "en", values: [:]),
                    StringsData(tableName: "Module2", language: "ja", values: [:]),
                ]
            ]
            XCTAssertEqual(actual, expect)
        }
    }

    func test_convertToXCStrings() throws {
        XCTContext.runActivity(named: "StringsData array is converted to XCStrings.") { _ in
            let sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "", verbose: false)
            let input: [StringsData] = [
                StringsData(
                    tableName: "Module1",
                    language: "en",
                    values: [
                        "\"Hello %@\"": .simple("\"Hello %@\""),
                        "Count = %lld": .simple("Count = %lld"),
                        "language": .simple("English"),
                        "path": .simple("/"),
                    ]
                ),
                StringsData(
                    tableName: "Module1", 
                    language: "ja", 
                    values: [
                        "\"Hello %@\"": .simple("「こんにちは%@」"),
                        "Count = %lld": .simple("カウント＝%lld"),
                        "language": .simple("日本語"),
                        "path": .simple("/"),
                    ]
                ),
            ]
            let actual = sut.convertToXCStrings(from: input)
            let expect = XCStrings(
                sourceLanguage: "test",
                strings: [
                    "\"Hello %@\"": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "\"Hello %@\"")),
                        "ja": Localization(stringUnit: StringUnit(value: "「こんにちは%@」")),
                    ]),
                    "Count = %lld": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "Count = %lld")),
                        "ja": Localization(stringUnit: StringUnit(value: "カウント＝%lld")),
                    ]),
                    "language": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "English")),
                        "ja": Localization(stringUnit: StringUnit(value: "日本語")),
                    ]),
                    "path": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "/")),
                        "ja": Localization(stringUnit: StringUnit(value: "/")),
                    ]),
                ],
                version: "1.0"
            )
            XCTAssertEqual(actual, expect)
        }
    }

    func test_exportXCStringsFile() throws {
        try XCTContext.runActivity(named: "If XCStrings is valid and verbose is false, file is successfully exported without outputting details.") { _ in
            var sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "output", verbose: false)
            var standardOutputs = [String]()
            sut.standardOutput = { items in
                standardOutputs.append(contentsOf: items.map({ "\($0)" }))
            }
            var writeDataCount: Int = 0
            sut.writeData = { _, url in
                XCTAssertEqual(url.path(), "output/Localizable.xcstrings")
                writeDataCount += 1
            }
            let input = XCStrings(
                sourceLanguage: "test",
                strings: [
                    "\"Hello %@\"": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "\"Hello %@\"")),
                        "ja": Localization(stringUnit: StringUnit(value: "「こんにちは%@」")),
                    ]),
                    "Count = %lld": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "Count = %lld")),
                        "ja": Localization(stringUnit: StringUnit(value: "カウント＝%lld")),
                    ]),
                    "language": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "English")),
                        "ja": Localization(stringUnit: StringUnit(value: "日本語")),
                    ]),
                    "path": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "/")),
                        "ja": Localization(stringUnit: StringUnit(value: "/")),
                    ]),
                ],
                version: "1.0"
            )
            try sut.exportXCStringsFile(name: "Localizable", input)
            let expect = ["Succeeded to export xcstrings files."]
            XCTAssertEqual(standardOutputs, expect)
            XCTAssertEqual(writeDataCount, 1)
        }
        try XCTContext.runActivity(named: "If XCStrings is valid and verbose is true, file is successfully exported with outputting details.") { _ in
            var sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "output", verbose: true)
            var standardOutputs = [String]()
            sut.standardOutput = { items in
                standardOutputs.append(contentsOf: items.map({ "\($0)" }))
            }
            var writeDataCount: Int = 0
            sut.writeData = { _, url in
                XCTAssertEqual(url.path(), "output/Localizable.xcstrings")
                writeDataCount += 1
            }
            let input = XCStrings(
                sourceLanguage: "test",
                strings: [
                    "\"Hello %@\"": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "\"Hello %@\"")),
                        "ja": Localization(stringUnit: StringUnit(value: "「こんにちは%@」")),
                    ]),
                    "Count = %lld": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "Count = %lld")),
                        "ja": Localization(stringUnit: StringUnit(value: "カウント＝%lld")),
                    ]),
                    "language": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "English")),
                        "ja": Localization(stringUnit: StringUnit(value: "日本語")),
                    ]),
                    "path": Strings(localizations: [
                        "en": Localization(stringUnit: StringUnit(value: "/")),
                        "ja": Localization(stringUnit: StringUnit(value: "/")),
                    ]),
                ],
                version: "1.0"
            )
            try sut.exportXCStringsFile(name: "Localizable", input)
            let details = #"""
                {
                  "sourceLanguage" : "test",
                  "strings" : {
                    "\"Hello %@\"" : {
                      "localizations" : {
                        "en" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "\"Hello %@\""
                          }
                        },
                        "ja" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "「こんにちは%@」"
                          }
                        }
                      }
                    },
                    "Count = %lld" : {
                      "localizations" : {
                        "en" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "Count = %lld"
                          }
                        },
                        "ja" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "カウント＝%lld"
                          }
                        }
                      }
                    },
                    "language" : {
                      "localizations" : {
                        "en" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "English"
                          }
                        },
                        "ja" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "日本語"
                          }
                        }
                      }
                    },
                    "path" : {
                      "localizations" : {
                        "en" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "/"
                          }
                        },
                        "ja" : {
                          "stringUnit" : {
                            "state" : "translated",
                            "value" : "/"
                          }
                        }
                      }
                    }
                  },
                  "version" : "1.0"
                }
                """#

            let expect = [details, "Succeeded to export xcstrings files."]
            XCTAssertEqual(standardOutputs, expect)
            XCTAssertEqual(writeDataCount, 1)
        }
        try XCTContext.runActivity(named: "If exporting file fails, an error is thrown.") { _ in
            var sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "", verbose: false)
            var standardOutputs = [String]()
            sut.standardOutput = { items in
                standardOutputs.append(contentsOf: items.map({ "\($0)" }))
            }
            sut.writeData = { _, _ in
                throw CocoaError(.fileWriteUnknown)
            }
            let input = XCStrings(sourceLanguage: "test", strings: [:], version: "1.0")
            XCTAssertThrowsError(try sut.exportXCStringsFile(name: "Localizable", input)) { error in
                XCTAssertEqual(error as? XMError, XMError.failedToExportXCStringsFile)
            }
        }
    }
}
