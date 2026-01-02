import Foundation

struct StringsFile: Equatable {
    var language: String
    var url: URL
    var type: FileType
    var tableName: String

    init?(language: String, url: URL) {
        self.language = language
        self.url = url
        guard let type = FileType(rawValue: url.pathExtension) else {
            return nil
        }
        self.type = type
        self.tableName = url.deletingPathExtension().lastPathComponent
    }

    enum FileType: String {
        case strings
        case stringsdict
    }
}
