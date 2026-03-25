//
//  SettingsManager.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import Combine

/// Minimal settings manager for the chat template
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var hapticFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled") }
    }

    @Published var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage") }
    }

    @Published var maxMessages: Int {
        didSet { UserDefaults.standard.set(maxMessages, forKey: "maxPromptMessages") }
    }

    @Published var webSearchEnabled: Bool {
        didSet { UserDefaults.standard.set(webSearchEnabled, forKey: "webSearchEnabled") }
    }

    @Published var isUsingCustomPrompt: Bool {
        didSet { UserDefaults.standard.set(isUsingCustomPrompt, forKey: "isUsingCustomPrompt") }
    }

    @Published var customSystemPrompt: String {
        didSet { UserDefaults.standard.set(customSystemPrompt, forKey: "customSystemPrompt") }
    }

    private init() {
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "System"
        self.maxMessages = UserDefaults.standard.object(forKey: "maxPromptMessages") as? Int ?? Constants.Context.defaultMaxMessages
        self.webSearchEnabled = UserDefaults.standard.object(forKey: "webSearchEnabled") as? Bool ?? false
        self.isUsingCustomPrompt = UserDefaults.standard.object(forKey: "isUsingCustomPrompt") as? Bool ?? false
        self.customSystemPrompt = UserDefaults.standard.string(forKey: "customSystemPrompt") ?? ""
    }
}
