//
//  ChatModels.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//


import Foundation
import UIKit

/// Represents a chat conversation
struct Chat: Identifiable, Codable {
    enum TitleState: String, Codable {
        case placeholder
        case generated
        case manual
    }

    static let placeholderTitle = "Untitled"

    let id: String
    var title: String
    var titleState: TitleState
    var messages: [Message]
    var hasActiveStream: Bool = false
    var createdAt: Date
    var modelType: ModelType
    var language: String?

    // Computed properties
    var isBlankChat: Bool {
        return messages.isEmpty
    }

    var needsGeneratedTitle: Bool {
        return titleState == .placeholder
    }

    /// Generates a permanent reverse-timestamp ID locally.
    /// Format: {reverseTimestamp padded to 13 digits}_{UUID}
    static func generateReverseId(timestampMs: Int = Int(Date().timeIntervalSince1970 * 1000)) -> String {
        let maxReverseTimestamp = 9999999999999
        let reverseTimestamp = maxReverseTimestamp - timestampMs
        let unpadded = String(reverseTimestamp)
        let digits = String(maxReverseTimestamp).count
        let reverseTsStr = String(repeating: "0", count: max(0, digits - unpadded.count)) + unpadded
        return "\(reverseTsStr)_\(UUID().uuidString.lowercased())"
    }

    static func deriveTitleState(for title: String, messages: [Message]) -> TitleState {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if messages.isEmpty {
            return normalizedTitle.isEmpty || normalizedTitle == placeholderTitle ? .placeholder : .manual
        }
        if normalizedTitle.isEmpty || normalizedTitle == placeholderTitle {
            return .placeholder
        }
        return .generated
    }

    init(
        id: String = Chat.generateReverseId(),
        title: String = Chat.placeholderTitle,
        titleState: TitleState? = nil,
        messages: [Message] = [],
        createdAt: Date = Date(),
        modelType: ModelType,
        language: String? = nil)
    {
        let resolvedTitleState = titleState ?? Chat.deriveTitleState(for: title, messages: messages)

        self.id = id
        self.title = title
        self.titleState = resolvedTitleState
        self.messages = messages
        self.createdAt = createdAt
        self.modelType = modelType
        self.language = language
    }

    // MARK: - Factory Methods

    /// Creates a new chat with the current model from AppConfig
    @MainActor
    static func create(
        id: String = Chat.generateReverseId(),
        title: String = Chat.placeholderTitle,
        titleState: TitleState? = nil,
        messages: [Message] = [],
        createdAt: Date = Date(),
        modelType: ModelType? = nil,
        language: String? = nil
    ) -> Chat {
        guard let model = modelType ?? AppConfig.shared.currentModel ?? AppConfig.shared.availableModels.first else {
            fatalError("Cannot create Chat without available models. Ensure AppConfig is initialized before creating chats.")
        }
        return Chat(
            id: id,
            title: title,
            titleState: titleState,
            messages: messages,
            createdAt: createdAt,
            modelType: model,
            language: language
        )
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, title, titleState, messages, createdAt, modelType, language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        messages = try container.decode([Message].self, forKey: .messages)
        titleState = (try? container.decode(TitleState.self, forKey: .titleState)) ?? Chat.deriveTitleState(for: title, messages: messages)
        // hasActiveStream is transient UI state — always reset to false on decode
        hasActiveStream = false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modelType = try container.decode(ModelType.self, forKey: .modelType)
        language = try container.decodeIfPresent(String.self, forKey: .language)
    }

    // MARK: - Haptic Feedback Methods

    /// Triggers haptic feedback when a chat operation succeeds
    static func triggerSuccessFeedback() {
        HapticFeedback.trigger(.success)
    }
}

/// Represents a message role
enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Web Search Types

/// Represents a source from web search results
struct WebSearchSource: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let url: String

    init(id: String = UUID().uuidString.lowercased(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(String.self, forKey: .url)
    }
}

/// Status of a web search operation
enum WebSearchStatus: String, Codable, Equatable {
    case searching
    case completed
    case failed
    case blocked
}

/// State of web search for a message
struct WebSearchState: Codable, Equatable {
    var query: String?
    var status: WebSearchStatus
    var sources: [WebSearchSource]
    var reason: String?

    init(
        query: String? = nil,
        status: WebSearchStatus = .searching,
        sources: [WebSearchSource] = [],
        reason: String? = nil
    ) {
        self.query = query
        self.status = status
        self.sources = sources
        self.reason = reason
    }
}

// MARK: - URL Fetch Types

/// Status of a URL fetch operation
enum URLFetchStatus: String, Codable, Equatable {
    case fetching
    case completed
    case failed
    case blocked
}

/// Tracks the state of a single URL being fetched during web search
struct URLFetchState: Codable, Equatable, Identifiable {
    let id: String
    let url: String
    var status: URLFetchStatus

    init(id: String = UUID().uuidString.lowercased(), url: String, status: URLFetchStatus = .fetching) {
        self.id = id
        self.url = url
        self.status = status
    }
}

/// URL citation from web search results
struct URLCitation: Codable, Equatable {
    let title: String
    let url: String
    let start_index: Int?
    let end_index: Int?
}

/// Annotation wrapper for URL citations
struct Annotation: Codable, Equatable {
    let type: String
    let url_citation: URLCitation
}

/// Represents a single message in a chat
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let role: MessageRole
    var content: String
    var thoughts: String? = nil
    var isThinking: Bool = false
    var timestamp: Date
    var isCollapsed: Bool = true
    var isStreaming: Bool = false
    var streamError: String? = nil
    var isRequestError: Bool = false
    var generationTimeSeconds: Double? = nil
    var contentChunks: [ContentChunk] = []
    var thinkingChunks: [ThinkingChunk] = []
    var webSearchState: WebSearchState? = nil
    var urlFetches: [URLFetchState] = []
    var attachments: [Attachment] = []

    // Passthrough fields for cross-platform round-trip
    var annotations: [Annotation]? = nil

    static let longMessageAttachmentThreshold = 1200
    var shouldDisplayAsAttachment: Bool {
        role == .user && content.count >= Message.longMessageAttachmentThreshold
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(id: String = UUID().uuidString.lowercased(), role: MessageRole, content: String, thoughts: String? = nil, isThinking: Bool = false, timestamp: Date = Date(), isCollapsed: Bool = true, generationTimeSeconds: Double? = nil, contentChunks: [ContentChunk] = [], thinkingChunks: [ThinkingChunk] = [], webSearchState: WebSearchState? = nil, attachments: [Attachment] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.thoughts = thoughts
        self.isThinking = isThinking
        self.timestamp = timestamp
        self.isCollapsed = isCollapsed
        self.generationTimeSeconds = generationTimeSeconds
        self.contentChunks = contentChunks
        self.thinkingChunks = thinkingChunks
        self.webSearchState = webSearchState
        self.attachments = attachments
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, role, content, thoughts, isThinking, timestamp, isCollapsed, isStreaming, streamError, isRequestError, generationTimeSeconds, webSearchState
        case webSearch // Alternative key used by React app
        case urlFetches
        case attachments
        case annotations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        thoughts = try container.decodeIfPresent(String.self, forKey: .thoughts)
        isThinking = try container.decodeIfPresent(Bool.self, forKey: .isThinking) ?? false

        // Handle timestamp as either Date or String (ISO8601)
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            timestamp = Self.iso8601Formatter.date(from: dateString)
                ?? Self.iso8601FormatterNoFractional.date(from: dateString)
                ?? Date()
        } else {
            timestamp = Date()
        }

        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? true
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
        streamError = try container.decodeIfPresent(String.self, forKey: .streamError)
        isRequestError = try container.decodeIfPresent(Bool.self, forKey: .isRequestError) ?? false
        generationTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .generationTimeSeconds)
        contentChunks = []
        thinkingChunks = []
        webSearchState = try container.decodeIfPresent(WebSearchState.self, forKey: .webSearchState)
            ?? container.decodeIfPresent(WebSearchState.self, forKey: .webSearch)
        urlFetches = try container.decodeIfPresent([URLFetchState].self, forKey: .urlFetches) ?? []
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        annotations = try container.decodeIfPresent([Annotation].self, forKey: .annotations)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role.rawValue, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(thoughts, forKey: .thoughts)
        try container.encode(isThinking, forKey: .isThinking)
        try container.encode(Self.iso8601Formatter.string(from: timestamp), forKey: .timestamp)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(isStreaming, forKey: .isStreaming)
        try container.encodeIfPresent(streamError, forKey: .streamError)
        if isRequestError { try container.encode(isRequestError, forKey: .isRequestError) }
        try container.encodeIfPresent(generationTimeSeconds, forKey: .generationTimeSeconds)
        try container.encodeIfPresent(webSearchState, forKey: .webSearch)
        if !urlFetches.isEmpty {
            try container.encode(urlFetches, forKey: .urlFetches)
        }
        if !attachments.isEmpty {
            try container.encode(attachments, forKey: .attachments)
        }
        try container.encodeIfPresent(annotations, forKey: .annotations)
    }
}

// MARK: - Haptic Feedback

/// Utility for handling haptic feedback in chat interactions
enum HapticFeedback {
    enum FeedbackType {
        case error
        case success
    }

    static func trigger(_ type: FeedbackType) {
        let hapticEnabled = UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
        guard hapticEnabled else { return }

        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .error:
            generator.notificationOccurred(.error)
        case .success:
            generator.notificationOccurred(.success)
        }
    }
}

