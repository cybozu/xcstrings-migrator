import ArgumentParser
import Darwin
import XCStringsMigrator

struct Migrate: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Migrate legacy strings file to xcstrings file."
    )

    @Option(
        name: [.customShort("l"), .customLong("source-language")],
        help: "Source language of the xcstrings file."
    )
    var sourceLanguage: String = "en"

    @Option(
        name: [.customShort("p"), .customLong("path")],
        parsing: ArrayParsingStrategy.singleValue,
        help: "Path to the lproj directory."
    )
    var paths: [String]

    @Option(
        name: [.customShort("o"), .customLong("output-directory")],
        help: "Path to the directory where you want to save the xcstrings file."
    )
    var outputPath: String

    @Flag(
        name: [.customShort("v"), .customLong("verbose")],
        help: "Provide detail output."
    )
    var verbose: Bool = false

    mutating func run() throws {
        do {
            try XMMigrator(
                sourceLanguage: sourceLanguage,
                paths: paths,
                outputPath: outputPath,
                verbose: verbose
            ).run()
        } catch let error as XMError {
            Swift.print("error:", error.errorDescription!)
            Darwin.exit(error.exitCode)
        }
    }
}
