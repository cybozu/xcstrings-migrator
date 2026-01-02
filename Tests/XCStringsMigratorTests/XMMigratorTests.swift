import Foundation
import Testing

@testable import XCStringsMigrator

@Suite(.serialized)
struct XMMigratorTests {
    @Test("If URL is invalid, nil will be returned.")
    func extractSingularValue_negative() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.resourceURL).appending(path: "not-exist.strings")
        let actual = sut.extractSingularValue(from: url)
        #expect(actual == nil)
    }

    @Test("If strings file is valid, dictionary will be returned.")
    func extractSingularValue_positive() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: "Migrator"))
        let actual = sut.extractSingularValue(from: url)
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
    func extractPluralValue_negative() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.resourceURL).appending(path: "not-exist.stringsdict")
        let actual = sut.extractPluralValue(from: url)
        #expect(actual == nil)
    }

    @Test("If stringsdict file is valid, dictionary will be returned.")
    func extractPluralValue_positive() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let url = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "stringsdict", subdirectory: "Migrator"))
        let actual = sut.extractPluralValue(from: url)
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
                items: [
                    .init(key: "\"Hello %@\"", value: .singular("\"Hello %@\"")),
                    .init(key: "Count = %lld", value: .singular("Count = %lld")),
                    .init(key: "key", value: .singular("value")),
                    .init(key: "path", value: .singular("/")),
                ]
            ),
            StringsData(
                tableName: "Localizable",
                language: "full",
                items: [
                    .init(key: "%lld item(s)", value: .plural([
                        .init(rule: .one, value: "%lld item"),
                        .init(rule: .other, value: "%lld items"),
                        .init(rule: .zero, value: "%lld item"),
                    ])),
                ]
            ),
        ]
        #expect(actual == expect)
    }

    @Test("StringsData array is classified by table name.")
    func classifyStringsData_positive() throws {
        let sut = XMMigrator(sourceLanguage: "", paths: [], outputPath: "", verbose: false)
        let input = [
            StringsData(tableName: "Module1", language: "en", items: []),
            StringsData(tableName: "Module1", language: "ja", items: []),
            StringsData(tableName: "Module2", language: "en", items: []),
            StringsData(tableName: "Module2", language: "ja", items: []),
        ]
        let actual = sut.classifyStringsData(with: input)
        let expect = [
            "Module1": [
                StringsData(tableName: "Module1", language: "en", items: []),
                StringsData(tableName: "Module1", language: "ja", items: []),
            ],
            "Module2": [
                StringsData(tableName: "Module2", language: "en", items: []),
                StringsData(tableName: "Module2", language: "ja", items: []),
            ]
        ]
        #expect(actual == expect)
    }

    @Test("StringsData array is converted to XCStrings.")
    func convertToXCStrings_positive() throws {
        let sut = XMMigrator(sourceLanguage: "test", paths: [], outputPath: "", verbose: false)
        let input = [
            StringsData(
                tableName: "Module1",
                language: "en",
                items: [
                    .init(key: "\"Hello %@\"", value: .singular("\"Hello %@\"")),
                    .init(key: "Count = %lld", value: .singular("Count = %lld")),
                    .init(key: "language", value: .singular("English")),
                    .init(key: "path", value: .singular("/")),
                    .init(key: "%lld item(s)", value: .plural([
                        .init(rule: .one, value: "%lld item"),
                        .init(rule: .other, value: "%lld items"),
                        .init(rule: .zero, value: "%lld item"),
                    ])),
                ]
            ),
            StringsData(
                tableName: "Module1",
                language: "ja",
                items: [
                    .init(key: "\"Hello %@\"", value: .singular("「こんにちは%@」")),
                    .init(key: "Count = %lld", value: .singular("カウント＝%lld")),
                    .init(key: "language", value: .singular("日本語")),
                    .init(key: "path", value: .singular("/")),
                    .init(key: "%lld item(s)", value: .plural([
                        .init(rule: .other, value: "%lld個"),
                        .init(rule: .zero, value: "%lld個"),
                    ])),
                ]
            ),
        ]
        let actual = sut.convertToXCStrings(from: input)
        let expect = XCStrings(
            sourceLanguage: "test",
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
                "path": XCStrings.Strings(localizations: [
                    "en": .stringUnit(.init(value: "/")),
                    "ja": .stringUnit(.init(value: "/")),
                ]),
                "%lld item(s)": .init(localizations: [
                    "en": .variations(.init(plural: [
                        "one": .init(stringUnit: .init(value: "%lld item")),
                        "zero": .init(stringUnit: .init(value: "%lld item")),
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
                        "one": .init(stringUnit: .init(value: "%lld item")),
                        "zero": .init(stringUnit: .init(value: "%lld item")),
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
                        "one": .init(stringUnit: .init(value: "%lld item")),
                        "zero": .init(stringUnit: .init(value: "%lld item")),
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
