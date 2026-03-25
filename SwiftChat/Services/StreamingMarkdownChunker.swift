//
//  StreamingMarkdownChunker.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation

enum ContentChunkType: Codable, Equatable, Hashable {
    case paragraph
    case codeBlock(language: String?)
    case heading
    case list
    case blockquote
    case table
    case other
}

struct ContentChunk: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let type: ContentChunkType
    let content: String
    let isComplete: Bool

    init(id: String = UUID().uuidString, type: ContentChunkType, content: String, isComplete: Bool) {
        self.id = id
        self.type = type
        self.content = content
        self.isComplete = isComplete
    }
}

class StreamingMarkdownChunker {
    private var completedChunks: [ContentChunk] = []
    private var workingBuffer: String = ""
    private var isInCodeBlock = false
    private var isInTable = false
    private var codeBlockLanguage: String?
    private var codeBlockFenceCount = 0
    private var isFinalized: Bool = false

    func getAllChunks() -> [ContentChunk] {
        var result = completedChunks

        if !workingBuffer.isEmpty {
            let chunkType: ContentChunkType = isInTable ? .table : (isInCodeBlock ? .codeBlock(language: codeBlockLanguage) : .paragraph)
            let chunkId = isInTable ? "working_table" : "working_current"
            result.append(ContentChunk(
                id: chunkId,
                type: chunkType,
                content: workingBuffer,
                isComplete: false
            ))
        }

        return result
    }

    @discardableResult
    func appendToken(_ token: String) -> Bool {
        workingBuffer += token

        if isInCodeBlock {
            if workingBuffer.hasSuffix("```") || workingBuffer.contains("\n```\n") || workingBuffer.contains("\n```") {
                if let closingRange = workingBuffer.range(of: "```", options: .backwards) {
                    let afterFence = String(workingBuffer[closingRange.upperBound...])
                    if afterFence.trimmingCharacters(in: .whitespaces).isEmpty || afterFence.hasPrefix("\n") {
                        finalizeCodeBlock(preserveAfterFence: afterFence)
                        return true
                    }
                }
            }
            return false
        }

        if isInTable {
            if workingBuffer.hasSuffix("\n\n") || (workingBuffer.hasSuffix("\n") && !workingBuffer.suffix(10).contains("|")) {
                finalizeTable()
                return true
            }
            return false
        }

        if workingBuffer.contains("```") {
            if let fenceRange = workingBuffer.range(of: "```") {
                let beforeFence = String(workingBuffer[..<fenceRange.lowerBound])

                if !beforeFence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let chunkId = "paragraph_\(beforeFence.hashValue)_\(Date().timeIntervalSince1970)"
                    completedChunks.append(ContentChunk(
                        id: chunkId,
                        type: .paragraph,
                        content: beforeFence,
                        isComplete: true
                    ))
                }

                let afterFence = String(workingBuffer[fenceRange.upperBound...])
                let langLine = afterFence.components(separatedBy: .newlines).first ?? ""
                codeBlockLanguage = langLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if codeBlockLanguage?.isEmpty == true {
                    codeBlockLanguage = nil
                }

                isInCodeBlock = true
                workingBuffer = String(workingBuffer[fenceRange.lowerBound...])
                return true
            }
        }

        let lines = workingBuffer.components(separatedBy: .newlines)
        if lines.count >= 2 {
            let lastTwo = lines.suffix(2)
            if lastTwo.allSatisfy({ $0.contains("|") }) {
                if lastTwo.last?.contains("---") == true || lastTwo.last?.contains(":--") == true || lastTwo.last?.contains("--:") == true {
                    isInTable = true
                    return false
                }
            }
        }

        if workingBuffer.hasSuffix("\n\n") && workingBuffer.count > 2 {
            let content = String(workingBuffer.dropLast(2))
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let chunkId = "paragraph_\(content.hashValue)_\(Date().timeIntervalSince1970)"
                completedChunks.append(ContentChunk(
                    id: chunkId,
                    type: .paragraph,
                    content: content,
                    isComplete: true
                ))
                workingBuffer = "\n\n"
                return true
            }
        }

        return false
    }

    private func finalizeCodeBlock(preserveAfterFence: String = "") {
        let chunkId = "codeblock_\(workingBuffer.hashValue)_\(Date().timeIntervalSince1970)"
        completedChunks.append(ContentChunk(
            id: chunkId,
            type: .codeBlock(language: codeBlockLanguage),
            content: workingBuffer,
            isComplete: true
        ))

        isInCodeBlock = false
        codeBlockLanguage = nil
        workingBuffer = preserveAfterFence
    }

    private func finalizeTable() {
        let trimmed = workingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let chunkId = "table_\(trimmed.hashValue)_\(Date().timeIntervalSince1970)"
            completedChunks.append(ContentChunk(
                id: chunkId,
                type: .table,
                content: trimmed,
                isComplete: true
            ))
        }

        isInTable = false
        workingBuffer = ""
    }

    func finalize() {
        isFinalized = true

        if isInCodeBlock {
            finalizeCodeBlock()
        } else if isInTable {
            finalizeTable()
        } else if !workingBuffer.isEmpty {
            let trimmed = workingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let chunkId = "paragraph_\(trimmed.hashValue)_\(Date().timeIntervalSince1970)"
                completedChunks.append(ContentChunk(
                    id: chunkId,
                    type: .paragraph,
                    content: trimmed,
                    isComplete: true
                ))
                workingBuffer = ""
            }
        }
    }

    func reset() {
        completedChunks.removeAll()
        workingBuffer = ""
        isInCodeBlock = false
        isInTable = false
        codeBlockLanguage = nil
        isFinalized = false
    }
}
