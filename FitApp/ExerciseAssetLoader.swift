// ExerciseAssetLoader.swift
// Loads exercise GIFs/images directly from Assets/ExerciseGIFs/ in the bundle.
// No network fallback — all assets are present locally after download.
// GIFs decoded frame-by-frame with ImageIO for smooth native animation.

import SwiftUI
import UIKit
import ImageIO
import Combine  // explicit import — fixes ObservableObject/Published build errors

// MARK: - Animated Exercise View

/// Drop-in view that plays an exercise GIF (or displays a PNG) from the local bundle.
/// Pass the filename without extension — the loader tries .gif then .png automatically.
struct AnimatedExerciseImage: View {
    /// Filename without extension, e.g. "push_up", "russian_twist"
    let filename: String
    var height: CGFloat = 220
    var cornerRadius: CGFloat = 16

    @StateObject private var loader = ExerciseGIFLoader()

    var body: some View {
        ZStack {
            // Dark background always visible behind the image
            Color(red: 0.06, green: 0.08, blue: 0.14)

            if loader.frames.isEmpty && !loader.didAttempt {
                // Waiting for load — show nothing (instant on local assets)
                EmptyView()
            } else if loader.frames.isEmpty {
                // File genuinely missing — show emoji placeholder
                placeholderView
            } else if loader.frames.count == 1 {
                // Static PNG
                Image(uiImage: loader.frames[0])
                    .resizable()
                    .scaledToFit()
            } else {
                // Animated GIF
                AnimatedFrameView(frames: loader.frames, delays: loader.delays)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { loader.load(filename: filename) }
        .accessibilityIdentifier("exercise_image_\(filename)")
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Text(filename.exerciseEmoji)
                .font(.system(size: 44))
            Text(filename.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
        }
    }
}

// MARK: - Animated Frame View

/// Cycles through GIF frames using each frame's native delay from the ImageIO decoder.
private struct AnimatedFrameView: View {
    let frames: [UIImage]
    let delays: [Double]

    @State private var currentIndex = 0
    @State private var animTimer: Timer?

    var body: some View {
        Image(uiImage: frames[currentIndex])
            .resizable()
            .scaledToFit()
            .onAppear(perform: startAnimation)
            .onDisappear { animTimer?.invalidate(); animTimer = nil }
    }

    private func startAnimation() {
        guard frames.count > 1 else { return }
        scheduleNext()
    }

    private func scheduleNext() {
        let delay = delays[safe: currentIndex] ?? 0.08
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            currentIndex = (currentIndex + 1) % frames.count
            scheduleNext()
        }
    }
}

// MARK: - GIF Loader

final class ExerciseGIFLoader: ObservableObject {
    @Published var frames: [UIImage] = []
    @Published var didAttempt = false
    private(set) var delays: [Double] = []

    /// Loads the file synchronously from the bundle (fast on local storage).
    /// Tries .gif first, then .png. Call once from .onAppear.
    func load(filename: String) {
        guard !didAttempt else { return }
        didAttempt = true

        for ext in ["gif", "png"] {
            // Try multiple bundle locations because project setups differ:
            // - group folders copied as resources (ExerciseGIFs / ExercisesGIFs)
            // - resources copied at bundle root
            let candidateData: Data? = {
                let directories = ["Assets/ExerciseGIFs", "Assets/ExercisesGIFs", "ExerciseGIFs", "ExercisesGIFs", ""]
                for dir in directories {
                    if let path = Bundle.main.path(
                        forResource: filename,
                        ofType: ext,
                        inDirectory: dir.isEmpty ? nil : dir
                    ),
                    let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        return data
                    }
                }
                return nil
            }()

            guard let data = candidateData else { continue }

            let (decodedFrames, decodedDelays) = Self.decode(data: data)
            if !decodedFrames.isEmpty {
                frames = decodedFrames
                delays = decodedDelays
                return   // stop after first successful extension
            }
        }

        // Fallback for asset-catalog entries (static image only).
        if let image = UIImage(named: filename) {
            frames = [image]
            delays = [0.1]
        }
        // If still not found, frames remains empty -> placeholder shows.
    }

    // MARK: ImageIO decoder

    static func decode(data: Data) -> ([UIImage], [Double]) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return ([], [])
        }
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var delays: [Double] = []

        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cg))
            delays.append(frameDelay(source: source, index: i))
        }
        return (images, delays)
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
        let gif   = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                 ?? gif?[kCGImagePropertyGIFDelayTime as String] as? Double
                 ?? 0.08
        return max(delay, 0.02)  // never faster than 20ms
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}

extension String {
    /// Returns a relevant emoji for an exercise filename when the image is missing.
    var exerciseEmoji: String {
        let l = lowercased()
        if l.contains("push")     || l.contains("bench")    || l.contains("fly")       { return "💪" }
        if l.contains("pull")     || l.contains("row")      || l.contains("lat")       { return "🏋️" }
        if l.contains("squat")    || l.contains("lunge")    || l.contains("deadlift")  { return "🦵" }
        if l.contains("hip")      || l.contains("calf")     || l.contains("press")     { return "🦾" }
        if l.contains("curl")     || l.contains("hammer")   || l.contains("dip")       { return "💪" }
        if l.contains("skull")    || l.contains("skull")                                { return "💪" }
        if l.contains("plank")    || l.contains("crunch")   || l.contains("twist")     { return "🔥" }
        if l.contains("mountain") || l.contains("leg")                                  { return "🔥" }
        if l.contains("burpee")   || l.contains("jump")     || l.contains("box")       { return "🏃" }
        if l.contains("face")     || l.contains("raise")                                { return "🦾" }
        return "⚡"
    }
}
