import Foundation

/// Minimal append-only logger to a file we can read while debugging.
/// Path: ~/Library/Application Support/OptionsBGone/optionsbgone.log
enum Log {
    static let url = ConfigStore.directory.appendingPathComponent("optionsbgone.log")

    static func write(_ msg: String) {
        let line = "\(Date()) \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(at: ConfigStore.directory, withIntermediateDirectories: true)
        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile()
            fh.write(data)
            try? fh.close()
        } else {
            try? data.write(to: url)
        }
    }
}
