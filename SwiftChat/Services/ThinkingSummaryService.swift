//
//  ThinkingSummaryService.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation

/// Service for generating thinking summaries during streaming.
/// Uses a simple tail-text extraction approach.
@MainActor
class ThinkingSummaryService {
    static let shared = ThinkingSummaryService()

    private var currentSummary: String = ""
    private var lastGenerationTime: Date?
    private var summarizedContentLength: Int = 0

    private init() {}

    /// Generate a summary of the thinking content by extracting the last sentence
    func generateSummary(thoughts: String, completion: @escaping @MainActor (String) -> Void) {
        let newContent = String(thoughts.dropFirst(summarizedContentLength))

        guard newContent.count >= Constants.ThinkingSummary.minContentLength else { return }

        if let lastTime = lastGenerationTime,
           Date().timeIntervalSince(lastTime) < Constants.ThinkingSummary.cooldownSeconds {
            return
        }

        lastGenerationTime = Date()
        summarizedContentLength = thoughts.count

        // Extract last meaningful sentence as a summary
        let words = thoughts.split(separator: " ")
        let tailText: String
        if words.count > 20 {
            tailText = words.suffix(20).joined(separator: " ")
        } else {
            tailText = thoughts
        }

        let trimmed = tailText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            currentSummary = trimmed
            completion(trimmed)
        }
    }

    /// Reset state for a new thinking session
    func reset() {
        currentSummary = ""
        lastGenerationTime = nil
        summarizedContentLength = 0
    }

    var summary: String {
        currentSummary
    }
}
