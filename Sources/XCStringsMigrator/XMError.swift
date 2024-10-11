import Foundation

public enum XMError: LocalizedError {
    case stringsFilesNotFound
    case xcstringsFileNotFound
    case xcstringsFileIsBroken
    case failedToExportXCStringsFile
    case failedToExportStringsFile

    public var errorDescription: String? {
        switch self {
        case .stringsFilesNotFound: "strings files not found."
        case .xcstringsFileNotFound: "xcstrings file not found."
        case .xcstringsFileIsBroken: "xcstrings file is broken."
        case .failedToExportXCStringsFile: "failed to export xcstrings file."
        case .failedToExportStringsFile: "failed to export strings file."
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .stringsFilesNotFound: 1
        case .xcstringsFileNotFound: 2
        case .xcstringsFileIsBroken: 3
        case .failedToExportXCStringsFile: 4
        case .failedToExportStringsFile: 5
        }
    }
}
