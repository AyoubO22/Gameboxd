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
    /// The data used without an account (and by versions before accounts).
    static let shared = FileStore()

    /// Each online account keeps its own data on the phone, so two accounts used on one
    /// phone never see each other's collection. Nil is the "no account" space.
    static func forAccount(_ id: UUID?, in guest: FileStore = .shared) -> FileStore {
        guard let id else { return guest }
        return FileStore(directory: guest.directory.appendingPathComponent("accounts/\(id.uuidString)", isDirectory: true),
                         legacyDefaults: nil)
    }

    let directory: URL
    /// Old versions kept data in UserDefaults; only the no-account space migrates it.
    private let legacyDefaults: UserDefaults?
    private let queue = DispatchQueue(label: "gameboxd.filestore", qos: .utility)

    init(directory: URL? = nil, legacyDefaults: UserDefaults? = .standard) {
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
        guard let data = fromFile ?? legacyDefaults?.data(forKey: key) else { return nil }

        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            if fromFile == nil {
                // Migrate from UserDefaults: keep the old copy until the file exists.
                try data.write(to: url, options: .atomic)
                legacyDefaults?.removeObject(forKey: key)
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
        legacyDefaults?.removeObject(forKey: key)
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// True when this space holds saved data (a collection, a profile…).
    var hasData: Bool {
        flush()
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.contains { $0.pathExtension == "json" }
    }

    /// Moves every saved file into `other` (the no-account collection becoming an account's
    /// when it is created). Moved, not copied: a second account can't receive it too.
    func moveContents(to other: FileStore) {
        flush()
        try? FileManager.default.createDirectory(at: other.directory, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            let target = other.directory.appendingPathComponent(file.lastPathComponent)
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.moveItem(at: file, to: target)
        }
    }

    /// Deletes this space's files (the account was deleted).
    func removeAll() {
        flush()
        try? FileManager.default.removeItem(at: directory)
    }

    /// Blocks until every queued write has been written to disk.
    func flush() {
        queue.sync {}
    }
}
