import ArgumentParser
import Darwin
import XCStringsMigrator

struct Revert: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Revert xcstrings file to legacy strings file."
    )

    @Option(
        name: [.customShort("p"), .customLong("path")],
        help: "Path to the xcstrings file."
    )
    var path: String

    @Option(
        name: [.customShort("o"), .customLong("output-directory")],
        help: "Path to the directory where you want to save the strings files."
    )
    var outputPath: String

    mutating func run() throws {
        do {
            try XMReverter(path: path, outputPath: outputPath).run()
        } catch let error as XMError {
            Swift.print("error:", error.errorDescription!)
            Darwin.exit(error.exitCode)
        }
    }
}
