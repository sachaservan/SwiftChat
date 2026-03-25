//
//  ThinkingTextChunker.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation

struct ThinkingChunk: Identifiable, Equatable, Hashable {
    let id: String
    let content: String
    let isComplete: Bool
}

class ThinkingTextChunker {
    private var completedChunks: [ThinkingChunk] = []
    private var workingBuffer: String = ""

    func getAllChunks() -> [ThinkingChunk] {
        var result = completedChunks

        if !workingBuffer.isEmpty {
            result.append(ThinkingChunk(
                id: "thinking_working_\(completedChunks.count)",
                content: workingBuffer,
                isComplete: false
            ))
        }

        return result
    }

    func appendToken(_ token: String) {
        workingBuffer += token

        // Split on double-newline paragraph boundaries
        while let range = workingBuffer.range(of: "\n\n") {
            let paragraph = String(workingBuffer[..<range.lowerBound])
            if !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let chunkId = "thinking_\(completedChunks.count)"
                completedChunks.append(ThinkingChunk(
                    id: chunkId,
                    content: paragraph,
                    isComplete: true
                ))
            }
            workingBuffer = String(workingBuffer[range.upperBound...])
        }
    }

    func finalize() {
        if !workingBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let chunkId = "thinking_\(completedChunks.count)"
            completedChunks.append(ThinkingChunk(
                id: chunkId,
                content: workingBuffer,
                isComplete: true
            ))
        }
        workingBuffer = ""
    }

    func reset() {
        completedChunks.removeAll()
        workingBuffer = ""
    }
}
