// DriveBackupService.swift
// Reads and writes ONE backup file (fitapp-backup.json) in the hidden Google Drive "appDataFolder".
// Only FitApp can see that folder, and it does not show up in the user's normal Drive.
// Owned and used ONLY by AppState.

import Foundation

/// A backup downloaded from the cloud, waiting for the user's decision.
struct CloudRestoreOffer: Identifiable {
    let id = UUID()
    let data: AppData
    let remoteModified: Date

    var profileName: String { data.profile.name }
    var workoutCount: Int { data.workoutHistory.count }
    var mealCount: Int { data.meals.count }
}

final class DriveBackupService {

    struct RemoteFile {
        let id: String
        let modified: Date
    }

    private static let fileName = "fitapp-backup.json"
    private static let filesURL = "https://www.googleapis.com/drive/v3/files"
    private static let uploadURL = "https://www.googleapis.com/upload/drive/v3/files"

    private let auth: GoogleAuthService

    init(auth: GoogleAuthService) {
        self.auth = auth
    }

    // MARK: - Operations

    /// The newest backup file, or nil when there is none.
    func find() async throws -> RemoteFile? {
        var components = URLComponents(string: Self.filesURL)!
        components.queryItems = [
            URLQueryItem(name: "spaces", value: "appDataFolder"),
            URLQueryItem(name: "q", value: "name = '\(Self.fileName)' and trashed = false"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "fields", value: "files(id,modifiedTime)")
        ]
        let (data, _) = try await send(URLRequest(url: components.url!))
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let files = json["files"] as? [[String: Any]],
              let first = files.first,
              let file = Self.remoteFile(from: first) else { return nil }
        return file
    }

    func download(_ file: RemoteFile) async throws -> Data {
        var components = URLComponents(string: "\(Self.filesURL)/\(file.id)")!
        components.queryItems = [URLQueryItem(name: "alt", value: "media")]
        let (data, _) = try await send(URLRequest(url: components.url!))
        return data
    }

    /// Creates the backup file, or replaces its content when `replacing` is given.
    func upload(_ content: Data, replacing existing: RemoteFile?) async throws -> RemoteFile {
        if let existing {
            do {
                return try await update(content, file: existing)
            } catch CloudError.notFound {
                // The file was deleted elsewhere: fall through and create it again.
            }
        }
        return try await create(content)
    }

    func delete(_ file: RemoteFile) async throws {
        var request = URLRequest(url: URL(string: "\(Self.filesURL)/\(file.id)")!)
        request.httpMethod = "DELETE"
        do {
            _ = try await send(request)
        } catch CloudError.notFound {
            // Already gone.
        }
    }

    // MARK: - Upload helpers

    private func create(_ content: Data) async throws -> RemoteFile {
        let boundary = "fitapp-\(UUID().uuidString)"
        let metadata = try JSONSerialization.data(withJSONObject: [
            "name": Self.fileName,
            "parents": ["appDataFolder"],
            "mimeType": "application/json"
        ])

        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        body.append(metadata)
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8))
        body.append(content)
        body.append(Data("\r\n--\(boundary)--".utf8))

        var components = URLComponents(string: Self.uploadURL)!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id,modifiedTime")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await sendForFile(request)
    }

    private func update(_ content: Data, file: RemoteFile) async throws -> RemoteFile {
        var components = URLComponents(string: "\(Self.uploadURL)/\(file.id)")!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "media"),
            URLQueryItem(name: "fields", value: "id,modifiedTime")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = content
        return try await sendForFile(request)
    }

    private func sendForFile(_ request: URLRequest) async throws -> RemoteFile {
        let (data, _) = try await send(request)
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let file = Self.remoteFile(from: json) else {
            throw CloudError.server(0)
        }
        return file
    }

    // MARK: - Networking

    /// Sends an authorised request. A 401 refreshes the token and retries once.
    private func send(_ original: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var token = try await auth.validAccessToken()
        for attempt in 0..<2 {
            var request = original
            request.timeoutInterval = 60
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw CloudError.network
            }
            guard let http = response as? HTTPURLResponse else { throw CloudError.network }

            switch http.statusCode {
            case 200..<300:
                return (data, http)
            case 401 where attempt == 0:
                token = try await auth.refreshAccessToken()
            case 401:
                throw CloudError.notSignedIn
            case 404:
                throw CloudError.notFound
            default:
                throw CloudError.server(http.statusCode)
            }
        }
        throw CloudError.notSignedIn
    }

    // MARK: - Parsing

    private static func remoteFile(from json: [String: Any]) -> RemoteFile? {
        guard let id = json["id"] as? String else { return nil }
        let modified = (json["modifiedTime"] as? String).flatMap(parseDate) ?? Date()
        return RemoteFile(id: id, modified: modified)
    }

    private static func parseDate(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }
}
