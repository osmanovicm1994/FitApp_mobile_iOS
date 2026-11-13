// GoogleAuthService.swift
// Google sign-in for FitApp's backup feature. No third-party SDK: OAuth 2.0 "authorization code
// + PKCE" through the system web sign-in sheet (ASWebAuthenticationSession), exactly what Google
// recommends for iOS apps. Owned and used ONLY by AppState.
//
// Scopes: "openid email" (to show which account is connected) and drive.appdata (a hidden,
// app-private folder in the user's Google Drive; FitApp cannot see any other Drive file).
//
// The long-lived refresh token is kept in the iOS Keychain (this device only, never backed up).

import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

// MARK: - Configuration

enum CloudConfig {
    /// Paste the iOS OAuth Client ID from Google Cloud Console (APIs & Services -> Credentials),
    /// e.g. "1011435231216-abcdefg.apps.googleusercontent.com".
    static let googleClientID = "1011435231216-7a1d0ikkngmgn9m8u7ff131vemmcdt0i.apps.googleusercontent.com"

    private static let clientIDSuffix = ".apps.googleusercontent.com"

    static var isConfigured: Bool {
        googleClientID.hasSuffix(clientIDSuffix) && !googleClientID.hasPrefix("PASTE")
    }

    /// Google's "reversed client ID" URL scheme, derived from the client ID.
    static var redirectScheme: String {
        "com.googleusercontent.apps." + googleClientID.replacingOccurrences(of: clientIDSuffix, with: "")
    }

    static var redirectURI: String { redirectScheme + ":/oauth2redirect" }

    static let scopes = "openid email https://www.googleapis.com/auth/drive.appdata"
}

// MARK: - Errors

enum CloudError: LocalizedError {
    case notConfigured
    case cancelled
    case notSignedIn
    case authFailed(String)
    case network
    case server(Int)
    case notFound
    case backupTooNew
    case backupUnreadable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google backup is not set up in this build yet."
        case .cancelled:
            return nil
        case .notSignedIn:
            return "Your Google sign-in expired. Please connect your Google account again."
        case .authFailed(let detail):
            return "Google sign-in failed. \(detail)"
        case .network:
            return "Could not reach Google. Check your internet connection and try again."
        case .server(let code):
            if code == 403 { return "Google refused the request (403). Make sure the Google Drive permission was granted, then try again." }
            return "Google returned an error (\(code)). Please try again later."
        case .notFound:
            return "The backup file was not found."
        case .backupTooNew:
            return "This backup was created by a newer version of FitApp. Please update the app to restore it."
        case .backupUnreadable:
            return "The backup could not be read, so nothing was changed."
        }
    }
}

// MARK: - Account (stored in the Keychain)

struct GoogleAccount: Codable {
    var refreshToken: String
    var email: String
    var autoBackup: Bool = true
    var lastBackupAt: Date? = nil
    /// Drive's modifiedTime of the backup file as of this device's last backup/restore.
    /// Used to notice when ANOTHER device has written a newer backup.
    var lastRemoteModified: Date? = nil
}

private enum KeychainStore {
    private static let service = "com.winter.FitApp.google"
    private static let account = "credentials"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> GoogleAccount? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(GoogleAccount.self, from: data)
    }

    static func save(_ account: GoogleAccount) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

// MARK: - Service

final class GoogleAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {

    private static let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!

    private(set) var account: GoogleAccount?
    private var accessToken: String?
    private var accessTokenExpiry = Date.distantPast
    private var session: ASWebAuthenticationSession?

    override init() {
        self.account = KeychainStore.load()
        super.init()
    }

    // MARK: Sign in

    func signIn() async throws -> GoogleAccount {
        guard CloudConfig.isConfigured else { throw CloudError.notConfigured }

        let verifier = Self.randomURLSafeString(byteCount: 48)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        let state = Self.randomURLSafeString(byteCount: 16)

        var components = URLComponents(string: Self.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: CloudConfig.googleClientID),
            URLQueryItem(name: "redirect_uri", value: CloudConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: CloudConfig.scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account consent")
        ]
        guard let url = components.url else { throw CloudError.authFailed("Invalid sign-in address.") }

        let callback = try await authenticate(url: url)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }

        if let error = value("error") {
            if error == "access_denied" { throw CloudError.cancelled }
            throw CloudError.authFailed(error)
        }
        guard value("state") == state, let code = value("code") else {
            throw CloudError.authFailed("The sign-in response was not valid.")
        }

        let json = try await postForm(Self.tokenURL, [
            "client_id": CloudConfig.googleClientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": CloudConfig.redirectURI,
            "grant_type": "authorization_code"
        ])

        guard let refreshToken = json["refresh_token"] as? String,
              let token = json["access_token"] as? String else {
            throw CloudError.authFailed("Google did not return the expected permission.")
        }
        let expires = (json["expires_in"] as? Double) ?? 3600
        accessToken = token
        accessTokenExpiry = Date().addingTimeInterval(expires)

        let email = Self.email(fromIDToken: json["id_token"] as? String) ?? "Google account"

        // Same account reconnecting keeps its sync settings; a different account starts fresh.
        var newAccount = GoogleAccount(refreshToken: refreshToken, email: email)
        if let old = account, old.email == email {
            newAccount.autoBackup = old.autoBackup
            newAccount.lastBackupAt = old.lastBackupAt
            newAccount.lastRemoteModified = old.lastRemoteModified
        }
        account = newAccount
        KeychainStore.save(newAccount)
        return newAccount
    }

    // MARK: Tokens

    func validAccessToken() async throws -> String {
        if let token = accessToken, accessTokenExpiry > Date().addingTimeInterval(60) { return token }
        return try await refreshAccessToken()
    }

    /// Forces a new access token (used after Drive answered 401).
    func refreshAccessToken() async throws -> String {
        guard let account else { throw CloudError.notSignedIn }
        do {
            let json = try await postForm(Self.tokenURL, [
                "client_id": CloudConfig.googleClientID,
                "refresh_token": account.refreshToken,
                "grant_type": "refresh_token"
            ])
            guard let token = json["access_token"] as? String else { throw CloudError.notSignedIn }
            accessToken = token
            accessTokenExpiry = Date().addingTimeInterval((json["expires_in"] as? Double) ?? 3600)
            return token
        } catch CloudError.notSignedIn {
            // Refresh token revoked or expired: forget the account.
            clearLocalAccount()
            throw CloudError.notSignedIn
        }
    }

    // MARK: Sync metadata

    func updateSync(_ change: (inout GoogleAccount) -> Void) {
        guard var current = account else { return }
        change(&current)
        account = current
        KeychainStore.save(current)
    }

    // MARK: Sign out

    func signOut(revoke: Bool) async {
        if revoke, let token = account?.refreshToken {
            _ = try? await postForm(Self.revokeURL, ["token": token])
        }
        clearLocalAccount()
    }

    private func clearLocalAccount() {
        account = nil
        accessToken = nil
        accessTokenExpiry = .distantPast
        KeychainStore.delete()
    }

    // MARK: Web sign-in sheet

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(CloudConfig.redirectScheme)
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let authError = error as? ASWebAuthenticationSessionError,
                          authError.code == .canceledLogin {
                    continuation.resume(throwing: CloudError.cancelled)
                } else {
                    continuation.resume(throwing: CloudError.authFailed(error?.localizedDescription ?? "Please try again."))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: CloudError.authFailed("The sign-in window could not be opened."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
    }

    // MARK: Helpers

    /// POSTs a form and returns the JSON object. 400/401 answers from the token endpoint mean the
    /// grant is no longer valid (`notSignedIn`).
    private func postForm(_ url: URL, _ params: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = params
            .map { key, value in
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CloudError.network
        }
        guard let http = response as? HTTPURLResponse else { throw CloudError.network }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        switch http.statusCode {
        case 200..<300:
            return json
        case 400, 401:
            if (json["error"] as? String) == "invalid_grant" || http.statusCode == 401 {
                throw CloudError.notSignedIn
            }
            throw CloudError.authFailed((json["error_description"] as? String) ?? (json["error"] as? String) ?? "Please try again.")
        default:
            throw CloudError.server(http.statusCode)
        }
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncoded
    }

    private static func email(fromIDToken token: String?) -> String? {
        guard let token else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return json["email"] as? String
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
