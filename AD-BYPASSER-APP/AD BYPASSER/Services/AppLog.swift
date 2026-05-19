import Foundation
import Observation

/// Tiny in-memory ring buffer of recent events so the Diagnostics view can show
/// what happened during DNS install/remove + API calls without us reaching for
/// Console.app or Xcode logs.
@MainActor
@Observable
final class AppLog {
    static let shared = AppLog()

    enum Level: String { case info, warn, error }
    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let tag: String
        let message: String
    }

    private(set) var entries: [Entry] = []
    private let limit = 200

    private init() {}

    func log(_ level: Level, _ tag: String, _ message: String) {
        entries.append(Entry(date: .now, level: level, tag: tag, message: message))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        #if DEBUG
        print("[\(tag)] \(level.rawValue): \(message)")
        #endif
    }

    func info(_ tag: String, _ message: String) { log(.info, tag, message) }
    func warn(_ tag: String, _ message: String) { log(.warn, tag, message) }
    func error(_ tag: String, _ message: String) { log(.error, tag, message) }

    func clear() { entries.removeAll() }
}
