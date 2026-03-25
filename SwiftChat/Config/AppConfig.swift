//
//  AppConfig.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation
import Combine
import OpenAI

/// A model available for chat
struct ModelType: Identifiable, Codable, Hashable, Equatable {
    let id: String
    let displayName: String
    let fullName: String
    let iconName: String
    let isMultimodal: Bool

    var modelName: String { id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ModelType, rhs: ModelType) -> Bool { lhs.id == rhs.id }
}

/// Application-wide configuration
@MainActor
class AppConfig: ObservableObject {
    static let shared = AppConfig()

    // MARK: - Configuration

    /// Set your API key here or via environment
    var apiKey: String = "YOUR_API_KEY"

    /// OpenAI-compatible API host (no scheme, no path)
    var apiHost: String = "api.openai.com"

    /// Base path for the API
    var apiBasePath: String = "/v1"

    /// System prompt sent with every conversation
    var systemPrompt: String = "You are a helpful AI assistant."

    /// Additional rules appended to the system prompt
    var rules: String = ""

    // MARK: - State

    @Published private(set) var isInitialized = false
    @Published private(set) var initializationError: Error?
    @Published var currentModel: ModelType? {
        didSet {
            if let model = currentModel {
                UserDefaults.standard.set(model.id, forKey: "selectedModel")
            }
        }
    }
    @Published private(set) var availableModels: [ModelType] = []
    @Published private(set) var networkMonitor = NetworkMonitor()

    private init() {
        setupDefaultModels()
        loadLastSelectedModel()
        isInitialized = true
    }

    // MARK: - Models

    /// Override this to change available models
    private func setupDefaultModels() {
        availableModels = [
            ModelType(id: "gpt-4.1", displayName: "GPT-4.1", fullName: "GPT-4.1", iconName: "openai-icon", isMultimodal: true),
            ModelType(id: "gpt-4.1-mini", displayName: "GPT-4.1 Mini", fullName: "GPT-4.1 Mini", iconName: "openai-icon", isMultimodal: true),
            ModelType(id: "o4-mini", displayName: "o4-mini", fullName: "o4-mini", iconName: "openai-icon", isMultimodal: true),
        ]
    }

    private func loadLastSelectedModel() {
        if let savedId = UserDefaults.standard.string(forKey: "selectedModel"),
           let model = availableModels.first(where: { $0.id == savedId }) {
            currentModel = model
        } else {
            currentModel = availableModels.first
        }
    }

    func filteredModelTypes() -> [ModelType] {
        return availableModels
    }

    /// The model used for generating chat titles (nil = skip title generation)
    var titleModel: ModelType? {
        availableModels.first(where: { $0.id == "gpt-4.1-mini" }) ?? availableModels.first
    }

    // MARK: - OpenAI Client

    func makeClient() -> OpenAI {
        let config = OpenAI.Configuration(
            token: apiKey,
            host: apiHost,
            basePath: apiBasePath
        )
        return OpenAI(configuration: config)
    }
}
