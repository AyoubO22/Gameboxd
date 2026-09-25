//
//  FileStore.swift
//  Gameboxd
//
//  Persists Codable values as JSON files in Application Support.
//

import Foundation

/// One JSON file per key, in Application Support.
///
/// Writes are atomic and run in order on a background queue, so saving never
/// blocks the UI and a crash mid-write can't leave a half-written file.
/// Data saved by older versions in UserDefaults is migrated on first load.
nonisolated final class FileStore: @unchecked Sendable {
    static let shared = FileStore()

    let directory: URL
    private let legacyDefaults: UserDefaults
    private let queue = DispatchQueue(label: "gameboxd.filestore", qos: .utility)

    init(directory: URL? = nil, legacyDefaults: UserDefaults = .standard) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gameboxd", isDirectory: true)
        self.legacyDefaults = legacyDefaults
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func url(for key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }

    func save<T: Encodable>(_ value: T, key: String) {
        let url = url(for: key)
        queue.async {
            do {
                try JSONEncoder().encode(value).write(to: url, options: .atomic)
            } catch {
                print("FileStore: failed to save \(key): \(error)")
            }
        }
    }

    /// Returns nil when nothing is stored or the stored bytes can't be decoded.
    /// Unreadable bytes are copied to a backup file first, so the next save can't
    /// silently destroy them.
    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        flush() // a pending write for this key must land before we read it
        let url = url(for: key)
        let fromFile = try? Data(contentsOf: url)
        guard let data = fromFile ?? legacyDefaults.data(forKey: key) else { return nil }

        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            if fromFile == nil {
                // Migrate from UserDefaults: keep the old copy until the file exists.
                try data.write(to: url, options: .atomic)
                legacyDefaults.removeObject(forKey: key)
            }
            return value
        } catch {
            let backup = directory.appendingPathComponent("\(key).unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? data.write(to: backup, options: .atomic)
            print("FileStore: failed to decode \(key), raw data backed up to \(backup.lastPathComponent): \(error)")
            return nil
        }
    }

    func remove(key: String) {
        let url = url(for: key)
        legacyDefaults.removeObject(forKey: key)
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Blocks until every queued write has been written to disk.
    func flush() {
        queue.sync {}
    }
}
