// PersistenceStore.swift
// Versioned, crash-safe storage for all FitApp data. Owned and used ONLY by AppState.
//
// Guarantees:
//   • Everything lives in ONE JSON file (Application Support/FitApp/fitapp-data.json) with a
//     `schemaVersion`, so the same format can be backed up to / restored from the cloud later.
//   • Writes are atomic: a crash mid-write can never leave a half-written file.
//   • A file that cannot be decoded is MOVED aside (fitapp-data.corrupt-<time>.json), never
//     overwritten, and the last good copy (fitapp-data.previous.json) is restored if possible.
//   • A file written by a NEWER app version is never touched (saving is disabled instead).

import Foundation
import os

// MARK: - Errors

enum PersistenceError: Error, LocalizedError {
    case newerSchema(Int)

    var errorDescription: String? {
        switch self {
        case .newerSchema(let version):
            return "This data was created by a newer version of FitApp (format \(version)). Please update the app."
        }
    }
}

// MARK: - Store

final class PersistenceStore {

    /// Bump when the JSON layout changes in a way older readers cannot cope with,
    /// and add a migration step in `decode(_:)`.
    static let currentSchemaVersion = 1

    enum LoadResult {
        /// Nothing stored yet (fresh install).
        case empty
        /// Normal load.
        case loaded(AppData)
        /// The main file was unreadable/missing; the last good copy was restored.
        case recovered(AppData, message: String)
        /// Nothing could be loaded. `allowSaving == false` means the on-disk data must not be touched.
        case failed(message: String, allowSaving: Bool)
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FitApp",
                                    category: "Persistence")

    private let directory: URL
    private var hasRotatedBackup = false

    private var fileURL: URL     { directory.appendingPathComponent("fitapp-data.json") }
    private var previousURL: URL { directory.appendingPathComponent("fitapp-data.previous.json") }

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("FitApp", isDirectory: true)
        }
    }

    // MARK: - Encoding (also used for cloud backup)

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        // Epoch milliseconds: compact and easy to read on Android/Kotlin too.
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    static func encode(_ data: AppData) throws -> Data {
        try makeEncoder().encode(data)
    }

    /// Decodes and validates data. Throws `PersistenceError.newerSchema` for data from a newer app,
    /// or a DecodingError for anything unreadable. The result is sanitised (values clamped to sane ranges).
    static func decode(_ raw: Data) throws -> AppData {
        let decoder = makeDecoder()
        let probe = try decoder.decode(VersionProbe.self, from: raw)
        if probe.schemaVersion > currentSchemaVersion {
            throw PersistenceError.newerSchema(probe.schemaVersion)
        }
        // Future: if probe.schemaVersion < currentSchemaVersion, upgrade the data here.
        var data = try decoder.decode(AppData.self, from: raw)
        data.sanitize()
        return data
    }

    // MARK: - Load

    func load() -> LoadResult {
        let fm = FileManager.default

        if fm.fileExists(atPath: fileURL.path) {
            let raw: Data
            do {
                raw = try Data(contentsOf: fileURL)
            } catch {
                // An I/O failure (for example the device is still locked after a reboot) is NOT a
                // corrupt file. Never quarantine or overwrite in this case.
                Self.log.error("Could not read data file: \(error.localizedDescription, privacy: .public)")
                return .failed(
                    message: "FitApp could not open its data file right now. Your data has not been changed. Please close and reopen the app.",
                    allowSaving: false
                )
            }

            do {
                return .loaded(try Self.decode(raw))
            } catch PersistenceError.newerSchema(let version) {
                Self.log.error("Data file has newer schema \(version)")
                return .failed(
                    message: "Your saved data was created by a newer version of FitApp. Please update the app. Your data has not been changed.",
                    allowSaving: false
                )
            } catch {
                Self.log.error("Data file is unreadable: \(error.localizedDescription, privacy: .public)")
                return recoverFromUnreadableFile()
            }
        }

        // Main file missing: maybe only the previous copy survived.
        if let previous = readPreviousBackup() {
            return .recovered(previous,
                              message: "Your main data file was missing, so the last saved copy was restored. Some recent changes may be missing.")
        }

        return .empty
    }

    private func recoverFromUnreadableFile() -> LoadResult {
        guard quarantineCurrentFile() else {
            return .failed(
                message: "Your saved data could not be read and could not be set aside safely. It has not been changed. Please restart the app.",
                allowSaving: false
            )
        }
        if let previous = readPreviousBackup() {
            return .recovered(previous,
                              message: "Your saved data could not be read, so the last good copy was restored. Some recent changes may be missing.")
        }
        return .failed(
            message: "Your saved data could not be read. A copy was kept on the device and the app started with empty data.",
            allowSaving: true
        )
    }

    private func readPreviousBackup() -> AppData? {
        guard let raw = try? Data(contentsOf: previousURL),
              let data = try? Self.decode(raw) else { return nil }
        return data
    }

    /// Moves the unreadable file aside so it is never overwritten.
    private func quarantineCurrentFile() -> Bool {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = directory.appendingPathComponent("fitapp-data.corrupt-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: target)
            return true
        } catch {
            Self.log.error("Could not quarantine file: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Save

    func save(_ data: AppData) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoded = try Self.encode(data)

        // Once per app launch, keep the state we started from as "previous".
        if !hasRotatedBackup {
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: previousURL)
                try? fm.copyItem(at: fileURL, to: previousURL)
            }
            hasRotatedBackup = true
        }

        try encoded.write(to: fileURL,
                          options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Keeps the data file as it is right now as the "previous" copy (safety net before a restore).
    func preserveCurrentAsPrevious() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        try? fm.removeItem(at: previousURL)
        try? fm.copyItem(at: fileURL, to: previousURL)
        hasRotatedBackup = true
    }

    // MARK: - Delete

    /// Removes the data file, its previous copy and any quarantined files.
    func deleteAllStoredData() {
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for item in items where item.lastPathComponent.hasPrefix("fitapp-data") {
                try? fm.removeItem(at: item)
            }
        }
        hasRotatedBackup = false
    }
}
