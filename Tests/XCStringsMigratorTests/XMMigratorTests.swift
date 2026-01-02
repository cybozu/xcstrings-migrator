import Foundation
import Testing

@testable import XCStringsMigrator

@Suite(.serialized)
struct XMMigratorTests {
    @Test("If URL is invalid, nil will be returned.")
    func extractKeyValue_negative() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.resourceURL).appending(path: "not-exist.strings")
        let actual = sut.extractKeyValue(from: url)
        #expect(actual == nil)
    }

    @Test("If strings file is valid, dictionary will be returned.")
    func extractKeyValue_positive() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: "Migrator"))
        let actual = sut.extractKeyValue(from: url)
        let expect = [
            "\"Hello %@\"": "\"Hello %@\"",
            "Count = %lld": "Count = %lld",
            "key": "value",
            "path": "/",
        ]
        #expect(actual == expect)
    }

    @Test("Extract variable name from formatKey (e.g., \"%#@format@\" -> \"format\")")
    func extractVariableName_positive() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let actual = sut.extractVariableName(from: "%#@format@")
        #expect(actual == "format")
    }

    @Test("If URL is invalid, nil will be returned.")
    func extractStringsDictValue_negative() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.resourceURL).appending(path: "not-exist.stringsdict")
        let actual = sut.extractStringsDictValue(from: url)
        #expect(actual == nil)
    }

    @Test("If stringsdict file is valid, dictionary will be returned.")
    func extractStringsDictValue_positive() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "stringsdict", subdirectory: "Migrator"))
        let actual = sut.extractStringsDictValue(from: url)
        let expect: [String: [String: String]] = [
            "%lld item(s)": [
                "zero": "%lld item",
                "one": "%lld item",
                "other": "%lld items"
            ]
        ]
        #expect(actual == expect)
    }

    @Test("If paths is empty, error is thrown.")
    func extractStringsData_negative_1() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        #expect(throws: XMError.stringsFilesNotFound) {
            try sut.extractStringsData()
        }
    }

    @Test("If path extension is not lproj, error is thrown.")
    func extractStringsData_negative_2() throws {
        let url = try #require(Bundle.module.resourceURL).appending(path: "dummy")
        let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
        #expect(throws: XMError.stringsFilesNotFound) {
            try sut.extractStringsData()
        }
    }

    @Test("If path extension is lproj but file does not exist, error is thrown.")
    func extractStringsData_negative_3() throws {
        let url = try #require(Bundle.module.resourceURL).appending(path: "not-exist.lproj")
        let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
        #expect(throws: XMError.stringsFilesNotFound) {
            try sut.extractStringsData()
        }
    }

    @Test("If path extension is lproj and file exists but contains no strings files, error is thrown.")
    func extractStringsData_negative_4() throws {
        let url = try #require(Bundle.module.url(forResource: "empty", withExtension: "lproj", subdirectory: "Migrator"))
        let sut = XMMigrator(sourceLanguage: "", paths: [url.path()], outputPath: "", verbose: false)
        #expect(throws: XMError.stringsFilesNotFound) {
            try sut.extractStringsData()
        }
    }

    @Test("If path extension is lproj and file exists and contains some strings files, array with elements is returned.")
    func extractStringsData_positive() throws {
        let url = try #require(Bundle.module.url(forResource: "full", withExtension: "lproj", subdirectory: "Migrator"))
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
            ),
            StringsData(
                tableName: "Localizable",
                language: "full",
                values: [
                    "%lld item(s)": .plural([
                        "other": "%lld items",
                        "one": "%lld item",
                        "zero": "%lld item",
                    ]),
                ]
            ),
        ]
        #expect(actual == expect)
    }

    @Test("StringsData array is classified by table name.")
    func classifyStringsData_positive() throws {
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
        #expect(actual == expect)
    }

    @Test("StringsData array is converted to XCStrings.")
    func convertToXCStrings_positive() throws {
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
                    "%lld item(s)": .plural([
                        "one": "%lld item",
                        "zero": "%lld item",
                        "other": "%lld items",
                    ]),
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
                    "%lld item(s)": .plural([
                        "zero": "%lld個",
                        "other": "%lld個",
                    ]),
                ]
            ),
        ]
        let actual = sut.convertToXCStrings(from: input)
        let expect = XCStrings(
            sourceLanguage: "test",
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
                        "one":  PluralVariation(stringUnit: .init(value: "%lld item")),
                        "zero": PluralVariation(stringUnit: .init(value: "%lld item")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld items")),
                    ])),
                    "ja": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "%lld個")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld個")),
                    ])),
                ]),
            ],
            version: "1.0"
        )
        #expect(actual == expect)
    }

    @Test("If exporting file fails, an error is thrown.")
    func exportXCStringsFile_negative() throws {
        var sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "", verbose: false)
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        sut.writeData = { _, _ in
            throw CocoaError(.fileWriteUnknown)
        }
        let input = XCStrings(sourceLanguage: "test", strings: [:], version: "1.0")
        #expect(throws: XMError.failedToExportXCStringsFile) {
            try sut.exportXCStringsFile(name: "Localizable", input)
        }
    }

    @Test("If XCStrings is valid and verbose is false, file is successfully exported without outputting details.")
    func exportXCStringsFile_positive_1() throws {
        var sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "output", verbose: false)
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        var writeDataCount = Int.zero
        sut.writeData = { _, url in
            #expect(url.path() == "output/Localizable.xcstrings")
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
                "%lld item(s)": Strings(localizations: [
                    "en": Localization(variations: .init(plural: [
                        "one":  PluralVariation(stringUnit: .init(value: "%lld item")),
                        "zero": PluralVariation(stringUnit: .init(value: "%lld item")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld items")),
                    ])),
                    "ja": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "%lld個")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld個")),
                    ])),
                ]),
            ],
            version: "1.0"
        )
        try sut.exportXCStringsFile(name: "Localizable", input)
        let expect = ["Succeeded to export xcstrings files."]
        #expect(standardOutputs == expect)
        #expect(writeDataCount == 1)
    }

    @Test("If XCStrings is valid and verbose is true, file is successfully exported with outputting details.")
    func exportXCStringsFile_positive_2() throws {
        var sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "output", verbose: true)
        var standardOutputs = [String]()
        sut.standardOutput = { items in
            standardOutputs.append(contentsOf: items.map({ "\($0)" }))
        }
        var writeDataCount = Int.zero
        sut.writeData = { _, url in
            #expect(url.path() == "output/Localizable.xcstrings")
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
                "%lld item(s)": Strings(localizations: [
                    "en": Localization(variations: .init(plural: [
                        "one":  PluralVariation(stringUnit: .init(value: "%lld item")),
                        "zero": PluralVariation(stringUnit: .init(value: "%lld item")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld items")),
                    ])),
                    "ja": Localization(variations: .init(plural: [
                        "zero": PluralVariation(stringUnit: .init(value: "%lld個")),
                        "other": PluralVariation(stringUnit: .init(value: "%lld個")),
                    ])),
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
                "%lld item(s)" : {
                  "localizations" : {
                    "en" : {
                      "variations" : {
                        "plural" : {
                          "one" : {
                            "stringUnit" : {
                              "state" : "translated",
                              "value" : "%lld item"
                            }
                          },
                          "other" : {
                            "stringUnit" : {
                              "state" : "translated",
                              "value" : "%lld items"
                            }
                          },
                          "zero" : {
                            "stringUnit" : {
                              "state" : "translated",
                              "value" : "%lld item"
                            }
                          }
                        }
                      }
                    },
                    "ja" : {
                      "variations" : {
                        "plural" : {
                          "other" : {
                            "stringUnit" : {
                              "state" : "translated",
                              "value" : "%lld個"
                            }
                          },
                          "zero" : {
                            "stringUnit" : {
                              "state" : "translated",
                              "value" : "%lld個"
                            }
                          }
                        }
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
        #expect(standardOutputs == expect)
        #expect(writeDataCount == 1)
    }
}
