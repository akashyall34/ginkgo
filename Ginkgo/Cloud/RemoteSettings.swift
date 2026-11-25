import Foundation
import GinkgoCore

/// Settings that change with no new build: stricter validator limits and the Gemini models. Every value is checked
/// before it's used; anything odd keeps the built-in value, and the validator can only get stricter.
enum RemoteSettings {
    static let modelsKey = "gemini_models"

    /// "gemini-a, gemini-b" → the model list. Any name that doesn't look like a Gemini model, or an empty list,
    /// keeps the built-in list: a typo must never leave the app with no model to call.
    static func models(from text: String, builtIn: [String] = AIRunner.builtInModels) -> [String] {
        let names = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let valid = names.allSatisfy { $0.range(of: #"^gemini-[a-z0-9.\-]+$"#, options: .regularExpression) != nil }
        return names.isEmpty || !valid ? builtIn : names
    }

    /// The validator values from Remote Config's numbers, by key name; missing or non-numeric keys are left out.
    static func validator(from numbers: [String: Double?]) -> ValidatorSettings {
        var remote: [ValidatorSettings.Key: Double] = [:]
        for key in ValidatorSettings.Key.allCases {
            if case let value?? = numbers[key.rawValue] { remote[key] = value }
        }
        return ValidatorSettings(remote: remote)
    }

    /// Applies checked values to the validator and the AI runner.
    static func apply(models text: String?, numbers: [String: Double?]) {
        AIRunner.models = text.map { models(from: $0) } ?? AIRunner.builtInModels
        ValidatorSettings.current = validator(from: numbers)
    }
}
