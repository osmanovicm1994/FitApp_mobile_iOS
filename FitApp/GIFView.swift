// GIFView.swift
// Native animated GIF rendering — no external packages needed.
// Uses UIImageView + ImageIO framework to decode GIF frames.
// Also provides GiphyService for fetching exercise GIFs dynamically.

import SwiftUI
import UIKit
import ImageIO       // For CGImageSource GIF decoding
import Combine       // explicit import

// MARK: - Native GIF Image View (UIViewRepresentable)

/// Renders any animated GIF from a URL using native UIKit + ImageIO.
/// Shows a gradient placeholder while loading.
struct GIFView: View {
    let url: String
    var cornerRadius: CGFloat = 12

    @StateObject private var loader = GIFLoader()

    var body: some View {
        Group {
            if let image = loader.animatedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if loader.isLoading {
                gifPlaceholder
            } else {
                gifErrorState
            }
        }
        .onAppear {
            guard let gifURL = URL(string: url) else { return }
            loader.load(from: gifURL)
        }
    }

    private var gifPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Loading…")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var gifErrorState: some View {
        ZStack {
            Color.secondary.opacity(0.1)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            VStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Preview unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - GIF Loader

/// ObservableObject that downloads GIF data and decodes it into
/// an animated UIImage using native ImageIO — no third-party packages.
final class GIFLoader: ObservableObject {
    @Published var animatedImage: UIImage?
    @Published var isLoading = false

    private var task: URLSessionDataTask?

    func load(from url: URL) {
        guard animatedImage == nil else { return }
        isLoading = true
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let data else { return }
                self?.animatedImage = UIImage.gif(data: data)
            }
        }
        task?.resume()
    }
}

// MARK: - UIImage GIF Extension

extension UIImage {
    /// Decodes GIF data into an animated UIImage using ImageIO.
    static func gif(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            // Static image
            if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return UIImage(cgImage: cgImage)
            }
            return nil
        }

        var frames: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let frameDuration = gifFrameDuration(source: source, at: i)
            totalDuration += frameDuration

            // Repeat each frame based on its delay to get smooth animation
            let repeatCount = max(Int(frameDuration / 0.016), 1)
            let frame = UIImage(cgImage: cgImage)
            for _ in 0..<repeatCount { frames.append(frame) }
        }

        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    private static func gifFrameDuration(source: CGImageSource, at index: Int) -> Double {
        let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
        let gifProps = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        let delay = gifProps?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                 ?? gifProps?[kCGImagePropertyGIFDelayTime as String] as? Double
                 ?? 0.1
        return delay < 0.011 ? 0.1 : delay
    }
}

// MARK: - Giphy Service

/// Fetches exercise demonstration GIFs from Giphy's public search API.
/// Rate-limited public beta key — replace with your own at giphy.com/developer.
final class GiphyService {
    static let shared = GiphyService()
    private init() {}

    // Giphy public beta key — rate-limited, fine for development/demo.
    // Register for free at https://developers.giphy.com to get your own key.
    private let apiKey = "dc6zaTOxFJmzC"
    private var cache: [String: String] = [:]

    func gifURL(for exerciseName: String) async -> String? {
        if let cached = cache[exerciseName] { return cached }

        let query = exerciseName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? exerciseName

        let urlString = "https://api.giphy.com/v1/gifs/search"
            + "?api_key=\(apiKey)"
            + "&q=\(query)+exercise+workout"
            + "&limit=1&rating=g&lang=en"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GiphyResponse.self, from: data)
            let gifURL = response.data.first?.images.original.url
            if let gifURL { cache[exerciseName] = gifURL }
            return gifURL
        } catch {
            return nil
        }
    }
}

// MARK: - Giphy Response Models

private struct GiphyResponse: Codable {
    let data: [GiphyGIF]
}

private struct GiphyGIF: Codable {
    let images: GiphyImages
}

private struct GiphyImages: Codable {
    let original: GiphyOriginal
}

private struct GiphyOriginal: Codable {
    let url: String
}

// MARK: - AsyncGIFView (fetches via Giphy API)

/// Fetches a GIF for an exercise name from Giphy, then displays it.
struct AsyncGIFView: View {
    let exerciseName: String
    var cornerRadius: CGFloat = 12

    @State private var gifURL: String?
    @State private var isFetching = true

    var body: some View {
        Group {
            if let url = gifURL {
                GIFView(url: url, cornerRadius: cornerRadius)
            } else if isFetching {
                placeholderView
            } else {
                fallbackView
            }
        }
        .task {
            gifURL = await GiphyService.shared.gifURL(for: exerciseName)
            isFetching = false
        }
    }

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                    .symbolEffect(.pulse)
                Text("Loading exercise…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            VStack(spacing: 6) {
                Text(exerciseEmoji(for: exerciseName))
                    .font(.system(size: 52))
                Text(exerciseName)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
    }

    private func exerciseEmoji(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("push") || n.contains("press") { return "💪" }
        if n.contains("squat") || n.contains("lunge") { return "🦵" }
        if n.contains("pull") || n.contains("row") { return "🏋️" }
        if n.contains("plank") || n.contains("core") { return "🧘" }
        if n.contains("run") || n.contains("cardio") || n.contains("jump") { return "🏃" }
        if n.contains("curl") || n.contains("bicep") { return "💪" }
        if n.contains("crunch") || n.contains("sit") { return "🔥" }
        return "⚡"
    }
}
