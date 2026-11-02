import Foundation

// Lets each service show the last successfully fetched data immediately on
// launch, even with no network connection, instead of only a spinner.
enum DCGCache {
    private struct Envelope<T: Codable>: Codable {
        let value: T
        let savedAt: Date
    }

    private static var directory: URL {
        let url = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DCGCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save<T: Codable>(_ value: T, as filename: String) {
        let envelope = Envelope(value: value, savedAt: Date())
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }

    static func load<T: Codable>(_ type: T.Type, from filename: String) -> (value: T, savedAt: Date)? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(filename)),
              let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data)
        else { return nil }
        return (envelope.value, envelope.savedAt)
    }
}
