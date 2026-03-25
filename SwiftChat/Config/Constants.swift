//
//  Constants.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation

/// Application-wide constants
enum Constants {
    enum UI {
        static let scrollToBottomButtonSize: CGFloat = 27
        static let scrollToBottomIconSize: CGFloat = 16
        static let tableMaxColumnWidth: CGFloat = 300
        static let tableFontSize: CGFloat = 16
        static let tableCellHorizontalPadding: CGFloat = 12
        static let actionButtonCornerRadius: CGFloat = 6
    }

    enum Rendering {
        static let maxSyntaxHighlightCharacters = 15_000
        static let maxFullParsingCharacters = 50_000
        static let maxMarkdownSegmentCharacters = 8_000
    }

    enum StreamingBuffer {
        static let initialMultiplier: CGFloat = 50.0
        static let multiplierIncrement: CGFloat = 10.0
        static let maxMultiplier: CGFloat = 200.0
        static let extensionThresholdRatio: CGFloat = 0.9
        static let maxCellHeight: CGFloat = 200_000
    }

    enum Pagination {
        static let chatsPerPage = 20
    }

    enum Context {
        static let defaultMaxMessages = 75
        static let maxMessagesLimit = 200
    }

    enum ThinkingSummary {
        static let minContentLength = 100
        static let cooldownSeconds: TimeInterval = 3.0
        static let tailWordCount = 200
    }

    enum TitleGeneration {
        static let wordThreshold = 100
        static let systemPrompt = "Generate a concise, descriptive title of minimum 2 words, maximum 5 words for the following text. NEVER output markdown."
    }

    enum Attachments {
        static let maxImageDimension: CGFloat = 768
        static let imageCompressionQuality: CGFloat = 0.85
        static let maxFileSizeBytes: Int64 = 20 * 1024 * 1024
        static let maxImageSizeBytes: Int64 = 10 * 1024 * 1024
        static let previewThumbnailSize: CGFloat = 60
        static let thumbnailMaxDimension: CGFloat = 300
        static let previewMaxWidth: CGFloat = 200
        static let messageThumbnailSize: CGFloat = 80
        static let messageThumbnailColumns: Int = 3
        static let supportedDocumentExtensions: Set<String> = ["pdf", "txt", "md", "csv", "html"]
        static let supportedImageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
        static let defaultImageMimeType = "image/jpeg"
    }

    enum Audio {
        static let sampleRate: Double = 44100
        static let numberOfChannels: Int = 1
        static let recordingTimeoutSeconds: TimeInterval = 120
        static let transcriptionModel = "whisper-1"
    }
}
