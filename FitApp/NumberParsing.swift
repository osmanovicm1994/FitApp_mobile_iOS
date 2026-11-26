// NumberParsing.swift
// Locale-safe number parsing/formatting and the validation limits used by the profile screens.
//
// Why this exists: on devices whose decimal separator is a comma (Bosnian, German, Swedish, ...)
// the decimal pad types "70,5". Swift's Double("70,5") returns nil, which used to silently
// turn the value into 0 or a default. NumberParsing accepts both "70,5" and "70.5".

import Foundation

enum NumberParsing {

    /// Parses "70.5" or "70,5". Returns nil for empty text, text with more than one separator,
    /// or anything that is not a finite number.
    static func double(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1 else { return nil }

        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    /// Parses a whole number. "12", "12.0" and "12,0" are accepted; "12.5" is not.
    static func int(from text: String) -> Int? {
        guard let value = double(from: text),
              value == value.rounded(),
              abs(value) < 1_000_000 else { return nil }
        return Int(value)
    }

    /// Rounds to one decimal place (the precision the UI shows), so what is saved is what is displayed.
    static func roundedToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// Formats for display in the user's locale: "82" for whole numbers, "82,5" / "82.5" otherwise.
    static func display(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// Accepted ranges for body stats. Used by onboarding, profile editing and data sanitising.
enum ProfileLimits {
    static let age: ClosedRange<Int>           = 10...100
    static let weightKg: ClosedRange<Double>   = 20...350
    static let heightCm: ClosedRange<Double>   = 100...250
}

/// Accepted range for one body measurement (wrist, arm, waist, ...) in centimetres.
enum MeasurementLimits {
    static let cm: ClosedRange<Double> = 3...300
}
