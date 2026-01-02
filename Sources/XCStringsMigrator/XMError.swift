import Foundation

public enum XMError: Int32, LocalizedError {
    case stringsFilesNotFound = 1
    case xcstringsFileNotFound
    case xcstringsFileIsBroken
    case failedToExportXCStringsFile
    case failedToExportStringsFile
    case failedToExportStringsDictFile

    public var errorDescription: String? {
        switch self {
        case .stringsFilesNotFound: "strings files not found."
        case .xcstringsFileNotFound: "xcstrings file not found."
        case .xcstringsFileIsBroken: "xcstrings file is broken."
        case .failedToExportXCStringsFile: "failed to export xcstrings file."
        case .failedToExportStringsFile: "failed to export strings file."
        case .failedToExportStringsDictFile: "failed to export stringsdict file."
        }
    }

    public var exitCode: Int32 { rawValue }
}
