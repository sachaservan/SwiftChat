//
//  MessageView.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import Textual
import SwiftMath
import UIKit

struct MessageView: View {
    let message: Message
    let isDarkMode: Bool
    let isLastMessage: Bool
    let isLoading: Bool
    let messageIndex: Int
    @EnvironmentObject var viewModel: SwiftChat.ChatViewModel
    @State private var showCopyFeedback = false
    @State private var cachedParsedContent: (thinkingText: String, remainderText: String, contentHash: Int)? = nil
    @State private var showLongMessageSheet = false
    @State private var showRawContentModal = false
    @State private var isEditMode = false
    @State private var editedContent = ""
    @State private var showSelectableText = false
    @State private var showSourcesSheet = false
    @State private var showUserMessageActions = false
    @State private var showThoughtsSheet = false
    @State private var showURLFetchSheet = false

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: .trailing, spacing: 4) {
            // Show attachment indicators above the message bubble
            if message.role == .user && !message.attachments.isEmpty {
                MessageAttachmentIndicator(
                    attachments: message.attachments,
                    isDarkMode: isDarkMode
                )
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                // Show the loading dots for a fresh streaming assistant response (but not if we have thoughts or are thinking)
                if message.role == .assistant &&
                    message.content.isEmpty &&
                    message.thoughts == nil &&
                    !message.isThinking &&
                    isLoading &&
                    isLastMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        if !message.urlFetches.isEmpty {
                            URLFetchBox(urlFetches: message.urlFetches, isDarkMode: isDarkMode, onTap: { showURLFetchSheet = true })
                        }

                        // Show web search box if searching
                        if let webSearchState = message.webSearchState {
                            WebSearchBox(
                                webSearchState: webSearchState,
                                isDarkMode: isDarkMode,
                                isStreaming: true,
                                webSearchSummary: viewModel.webSearchSummary,
                                onTap: { showSourcesSheet = true }
                            )
                        }

                        // Show loading dots if no web search or search is complete
                        if message.webSearchState == nil || message.webSearchState?.status != .searching {
                            LoadingDotsView(isDarkMode: isDarkMode)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // If the message is thinking or has thoughts, display them in a thinking box
                else if message.isThinking || message.thoughts != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if !message.urlFetches.isEmpty {
                            URLFetchBox(urlFetches: message.urlFetches, isDarkMode: isDarkMode, onTap: { showURLFetchSheet = true })
                        }

                        // Web search box (if applicable) - shown before thoughts since search happens first
                        if let webSearchState = message.webSearchState {
                            WebSearchBox(
                                webSearchState: webSearchState,
                                isDarkMode: isDarkMode,
                                isStreaming: isLoading && isLastMessage,
                                webSearchSummary: isLastMessage ? viewModel.webSearchSummary : nil,
                                onTap: { showSourcesSheet = true }
                            )
                        }

                        CollapsibleThinkingBox(
                            thinkingText: message.thoughts ?? "",
                            isDarkMode: isDarkMode,
                            isStreaming: message.isThinking && isLoading && isLastMessage,
                            generationTimeSeconds: message.generationTimeSeconds,
                            thinkingSummary: isLastMessage && message.isThinking ? viewModel.thinkingSummary : nil,
                            onTap: { showThoughtsSheet = true }
                        )

                        if !message.content.isEmpty {
                            if !message.contentChunks.isEmpty {
                                ChunkedContentView(chunks: message.contentChunks, isDarkMode: isDarkMode, isStreaming: isLoading && isLastMessage)
                                    .equatable()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                LaTeXMarkdownView(content: message.content, isDarkMode: isDarkMode, isStreaming: isLoading && isLastMessage)
                                    .equatable()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transaction { transaction in
                                        transaction.animation = nil
                                    }
                            }
                        }
                    }
                }
                
                // Legacy support: if content still has <think> tags, parse and display
                else if let parsed = getParsedMessageContent() {
                    VStack(alignment: .leading, spacing: 4) {
                        CollapsibleThinkingBox(
                            thinkingText: parsed.thinkingText,
                            isDarkMode: isDarkMode,
                            isStreaming: isLoading && isLastMessage,
                            generationTimeSeconds: message.generationTimeSeconds,
                            thinkingSummary: isLastMessage && !message.content.contains("</think>") ? viewModel.thinkingSummary : nil,
                            onTap: { showThoughtsSheet = true }
                        )
                        
                        // Remainder: text after </think> if present
                        if !parsed.remainderText.isEmpty {
                            LaTeXMarkdownView(content: parsed.remainderText, isDarkMode: isDarkMode, isStreaming: isLoading && isLastMessage)
                                .equatable()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                        }
                    }
                }
                
                // Display long user messages as an attachment-style preview that expands on tap
                else if message.role == .user && message.shouldDisplayAsAttachment {
                    if isEditMode {
                        UserMessageEditView(
                            content: $editedContent,
                            isDarkMode: isDarkMode,
                            onSave: {
                                viewModel.editMessage(at: messageIndex, newContent: editedContent)
                                isEditMode = false
                            },
                            onCancel: {
                                isEditMode = false
                                editedContent = message.content
                            }
                        )
                    } else {
                        LongMessageAttachmentView(message: message, isDarkMode: isDarkMode) {
                            showLongMessageSheet = true
                        }
                    }
                }

                else if !message.content.isEmpty {
                    if message.role == .user {
                        if isEditMode {
                            UserMessageEditView(
                                content: $editedContent,
                                isDarkMode: isDarkMode,
                                onSave: {
                                    viewModel.editMessage(at: messageIndex, newContent: editedContent)
                                    isEditMode = false
                                },
                                onCancel: {
                                    isEditMode = false
                                    editedContent = message.content
                                }
                            )
                        } else {
                            AdaptiveMarkdownText(content: message.content, isDarkMode: isDarkMode)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            if !message.urlFetches.isEmpty {
                                URLFetchBox(urlFetches: message.urlFetches, isDarkMode: isDarkMode, onTap: { showURLFetchSheet = true })
                            }

                            // Web search box for non-thinking assistant messages
                            if let webSearchState = message.webSearchState {
                                WebSearchBox(
                                    webSearchState: webSearchState,
                                    isDarkMode: isDarkMode,
                                    isStreaming: isLoading && isLastMessage,
                                    webSearchSummary: isLastMessage ? viewModel.webSearchSummary : nil,
                                    onTap: { showSourcesSheet = true }
                                )
                            }

                            if !message.contentChunks.isEmpty {
                                ChunkedContentView(chunks: message.contentChunks, isDarkMode: isDarkMode, isStreaming: isLoading && isLastMessage)
                                    .equatable()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                LaTeXMarkdownView(content: message.content, isDarkMode: isDarkMode, isStreaming: isLoading && isLastMessage)
                                    .equatable()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                // Show error box with regenerate button if stream failed
                if message.streamError != nil && message.role == .assistant {
                    ErrorMessageView(
                        errorMessage: message.streamError!,
                        isDarkMode: isDarkMode,
                        isRequestError: message.isRequestError,
                        onRegenerate: isLastMessage ? { viewModel.regenerateLastResponse() } : nil
                    )
                    .padding(.top, message.content.isEmpty && message.thoughts == nil ? 0 : 8)
                }
                
                // Add action buttons for assistant messages (only when not streaming)
                if message.role == .assistant &&
                   (!message.content.isEmpty || message.thoughts != nil) &&
                   !(isLoading && isLastMessage) {
                    HStack(spacing: 16) {
                        // Sources button - only show if we have web search sources
                        if let webSearchState = message.webSearchState,
                           !webSearchState.sources.isEmpty {
                            SourcesButton(
                                sources: webSearchState.sources,
                                isDarkMode: isDarkMode
                            ) {
                                showSourcesSheet = true
                            }
                        }

                        Button {
                            showRawContentModal = true
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Regenerate button - only on the last assistant message
                        if isLastMessage && !viewModel.isLoading && messageIndex > 0 {
                            Button {
                                viewModel.regenerateMessage(at: messageIndex - 1)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // AI disclaimer - only on the last assistant message
                    if isLastMessage {
                        Text("AI can make mistakes. Verify important information.")
                            .font(.system(size: 11))
                            .foregroundColor(isDarkMode ? .white.opacity(0.35) : .black.opacity(0.35))
                    }
                }

                }
                .padding(.vertical, message.role == .user && message.content.isEmpty ? 0 : 8)
                .padding(.horizontal, message.role == .user && !message.content.isEmpty ? 12 : 0)
                .background {
                    if message.role == .user && !message.content.isEmpty {
                        if #available(iOS 26, *) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thickMaterial)
                        } else {
                            Color.userMessageBackground(isDarkMode: isDarkMode)
                        }
                    }
                }
                .cornerRadius(16)
                .modifier(MessageBubbleModifier(isUserMessage: message.role == .user))
                .contextMenu {
                    if message.role == .user && !message.content.isEmpty {
                        Button {
                            viewModel.regenerateMessage(at: messageIndex)
                        } label: {
                            Label("Resend", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)

                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        Button {
                            editedContent = message.content
                            isEditMode = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
                .onChange(of: message.id) { _, _ in
                    isEditMode = false
                    editedContent = ""
                }
                .onChange(of: viewModel.editRequestedForMessageIndex) { _, newValue in
                    if newValue == messageIndex && message.role == .user {
                        editedContent = message.content
                        isEditMode = true
                        viewModel.editRequestedForMessageIndex = nil
                    }
                }

            }
        }
        .padding(.horizontal, 4)
        .sheet(isPresented: $showLongMessageSheet) {
            LongMessageDetailView(
                message: message
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRawContentModal) {
            RawContentModalView(message: message)
                .presentationDetents([.medium, .large])
                .presentationBackground(isDarkMode ? Color(hex: "161616") : Color(UIColor.systemGroupedBackground))
        }
        .sheet(isPresented: $showSelectableText) {
            UserMessageSelectView(content: message.content)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSourcesSheet) {
            if let sources = message.webSearchState?.sources {
                SourcesSheetView(sources: sources, isDarkMode: isDarkMode)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showThoughtsSheet) {
            ThoughtsSheetView(
                thinkingText: thoughtsContent ?? "",
                thinkingChunks: message.thinkingChunks,
                generationTimeSeconds: message.generationTimeSeconds,
                isDarkMode: isDarkMode
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(isDarkMode ? Color(hex: "161616") : Color(UIColor.systemGroupedBackground))
        }
        .sheet(isPresented: $showURLFetchSheet) {
            URLFetchSheetView(urlFetches: message.urlFetches, isDarkMode: isDarkMode)
                .presentationDetents([.medium, .large])
                .presentationBackground(isDarkMode ? Color(hex: "161616") : Color(UIColor.systemGroupedBackground))
        }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "cite" {
                let path = url.absoluteString.dropFirst(5)
                if let tildeIndex = path.firstIndex(of: "~") {
                    let afterFirstTilde = path[path.index(after: tildeIndex)...]
                    if let secondTildeIndex = afterFirstTilde.firstIndex(of: "~") {
                        let encodedUrl = String(afterFirstTilde[..<secondTildeIndex])
                        if let decodedUrl = encodedUrl.removingPercentEncoding,
                           let sourceURL = URL(string: decodedUrl) {
                            UIApplication.shared.open(sourceURL)
                            return .handled
                        }
                    }
                }
                return .handled
            }
            return .systemAction
        })
    }

    private func copyMessagePart(_ text: String) {
        let cleanText = removeThinktags(from: text)
        
        #if os(macOS)
        if let pasteboard = NSPasteboard.general {
            pasteboard.clearContents()
            pasteboard.setString(cleanText, forType: .string)
        }
        #elseif os(iOS)
        UIPasteboard.general.string = cleanText
        #endif
        
        withAnimation {
            showCopyFeedback = true
        }
        
        // Hide the feedback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopyFeedback = false
            }
        }
    }
    
    // Remove think tags from text if present
    private func removeThinktags(from text: String) -> String {
        guard text.hasPrefix("<think>") else { return text }
        
        // If the text has think tags, we need to clean it up
        if let endTagRange = text.range(of: "</think>") {
            // Get just the text after the closing think tag
            return String(text[endTagRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return text.replacingOccurrences(of: "<think>", with: "")
    }
    
    private var thoughtsContent: String? {
        if let thoughts = message.thoughts, !thoughts.isEmpty {
            return thoughts
        }
        if message.content.hasPrefix("<think>") {
            let tagPrefix = "<think>"
            let tagSuffix = "</think>"
            let start = message.content.index(message.content.startIndex, offsetBy: tagPrefix.count)

            if let endTagRange = message.content.range(of: tagSuffix, range: start..<message.content.endIndex) {
                return String(message.content[start..<endTagRange.lowerBound])
            } else {
                return String(message.content[start...])
            }
        }
        return nil
    }

    private var responseContent: String {
        if message.thoughts != nil {
            return message.content.hasPrefix("<think>") ? "" : message.content
        }
        if message.content.hasPrefix("<think>") {
            let tagSuffix = "</think>"
            if let endTagRange = message.content.range(of: tagSuffix) {
                return String(message.content[endTagRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return message.content
    }

    /// Parse message content with <think> tags
    private func getParsedMessageContent() -> (thinkingText: String, remainderText: String)? {
        // Parse if content starts with <think>
        guard message.content.hasPrefix("<think>") else { return nil }
        
        let tagPrefix = "<think>"
        let tagSuffix = "</think>"
        let start = message.content.index(message.content.startIndex, offsetBy: tagPrefix.count)
        
        if let endTagRange = message.content.range(of: tagSuffix, range: start..<message.content.endIndex) {
            let thinkingText = String(message.content[start..<endTagRange.lowerBound])
            let remainderText = String(message.content[endTagRange.upperBound...])
            return (thinkingText, remainderText)
        } else {
            // If the closing tag hasn't been received, treat all text after <think> as the thinking text.
            let thinkingText = String(message.content[start...])
            return (thinkingText, "")
        }
    }
}

private struct LongMessageAttachmentView: View {
    let message: Message
    let isDarkMode: Bool
    let openAction: () -> Void

    private var wordCountText: String {
        let words = message.content.split { $0.isWhitespace || $0.isNewline }
        return "\(words.count) words"
    }

    private var previewText: String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = trimmed.prefix(180)
        return preview + (trimmed.count > 180 ? "…" : "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color.userMessageForeground(isDarkMode: isDarkMode).opacity(0.85))

            VStack(alignment: .leading, spacing: 6) {
                Text("Long Message")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.userMessageForeground(isDarkMode: isDarkMode))

                Text(wordCountText)
                    .font(.system(size: 12))
                    .foregroundColor(Color.userMessageForeground(isDarkMode: isDarkMode).opacity(0.6))

                Text(previewText)
                    .font(.system(size: 14))
                    .foregroundColor(Color.userMessageForeground(isDarkMode: isDarkMode).opacity(0.85))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.userMessageForeground(isDarkMode: isDarkMode).opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: openAction)
    }
}

private struct LongMessageDetailView: View {
    let message: Message

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                SelectableTextView(text: message.content)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.backgroundPrimary)
            .navigationTitle("Long Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SelectableTextView: UIViewRepresentable {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.alwaysBounceVertical = true
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = colorScheme == .dark ? UIColor(white: 1.0, alpha: 0.92) : UIColor(white: 0.0, alpha: 0.92)
    }
}

private struct UserMessageSelectView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SelectableTextView(text: content)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
                .background(Color.backgroundPrimary)
                .navigationTitle("Select Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RawContentModalView: View {
    let message: Message

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopyAllFeedback = false
    @State private var showCopyResponseFeedback = false
    @State private var showCopyThoughtsFeedback = false

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var hasThoughts: Bool {
        if let thoughts = message.thoughts, !thoughts.isEmpty {
            return true
        }
        return message.content.hasPrefix("<think>")
    }

    private var thoughtsContent: String? {
        if let thoughts = message.thoughts, !thoughts.isEmpty {
            return thoughts
        }
        if message.content.hasPrefix("<think>") {
            let tagPrefix = "<think>"
            let tagSuffix = "</think>"
            let start = message.content.index(message.content.startIndex, offsetBy: tagPrefix.count)

            if let endTagRange = message.content.range(of: tagSuffix, range: start..<message.content.endIndex) {
                return String(message.content[start..<endTagRange.lowerBound])
            } else {
                return String(message.content[start...])
            }
        }
        return nil
    }

    private var responseContent: String {
        if message.thoughts != nil {
        return message.content.hasPrefix("<think>") ? "" : message.content
        }
        if message.content.hasPrefix("<think>") {
            let tagSuffix = "</think>"
            if let endTagRange = message.content.range(of: tagSuffix) {
                return String(message.content[endTagRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return message.content
    }

    private var fullRawContent: String {
        if let thoughts = thoughtsContent, !thoughts.isEmpty {
            if !responseContent.isEmpty {
                return thoughts + "\n\n" + responseContent
            }
            return thoughts
        }
        return responseContent
    }

    private var sheetBackground: Color {
        isDarkMode ? Color(hex: "161616") : Color(UIColor.systemGroupedBackground)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SelectableTextView(text: fullRawContent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)

                Divider()

                VStack(spacing: 10) {
                    copyButton(
                        action: copyAll,
                        icon: showCopyAllFeedback ? "checkmark" : "doc.on.doc",
                        label: showCopyAllFeedback ? "Copied All!" : "Copy All"
                    )

                    if hasThoughts && !responseContent.isEmpty {
                        copyButton(
                            action: copyResponse,
                            icon: showCopyResponseFeedback ? "checkmark" : "text.quote",
                            label: showCopyResponseFeedback ? "Copied Response!" : "Copy Response"
                        )
                    }

                    if hasThoughts {
                        copyButton(
                            action: copyThoughts,
                            icon: showCopyThoughtsFeedback ? "checkmark" : "brain",
                            label: showCopyThoughtsFeedback ? "Copied Thoughts!" : "Copy Thoughts"
                        )
                    }
                }
                .padding(20)
            }
            .background(sheetBackground)
            .navigationTitle("Raw Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
    }

    private func copyButton(action: @escaping () -> Void, icon: String, label: String) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.brandAccentDark)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func copyAll() {
        UIPasteboard.general.string = fullRawContent
        withAnimation {
            showCopyAllFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopyAllFeedback = false
            }
        }
    }

    private func copyResponse() {
        UIPasteboard.general.string = responseContent
        withAnimation {
            showCopyResponseFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopyResponseFeedback = false
            }
        }
    }

    private func copyThoughts() {
        if let thoughts = thoughtsContent {
            UIPasteboard.general.string = thoughts
            withAnimation {
                showCopyThoughtsFeedback = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showCopyThoughtsFeedback = false
                }
            }
        }
    }
}

/// Modifier that handles message bubble sizing based on sender
struct MessageBubbleModifier: ViewModifier {
    let isUserMessage: Bool
    
    func body(content: Content) -> some View {
        Group {
            if isUserMessage {
                content
                    // User messages get adaptive width based on content with minimum width
                    .frame(minWidth: 60, idealWidth: nil, maxWidth: max(60, UIScreen.main.bounds.width * 0.85), alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                content
                    // Assistant messages get nearly full width
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// A view that renders Markdown content using the Textual library.
struct MarkdownText: View {
    let content: String
    let isDarkMode: Bool
    let horizontalPadding: CGFloat

    init(content: String, isDarkMode: Bool, horizontalPadding: CGFloat = 0) {
        self.content = content
        self.isDarkMode = isDarkMode
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        StructuredText(markdown: content)
            .textual.structuredTextStyle(.gitHub)
            .textual.highlighterTheme(.default)
            .textual.textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, horizontalPadding)
            .environment(\.colorScheme, isDarkMode ? .dark : .light)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A specialized markdown text view for user messages
struct AdaptiveMarkdownText: View {
    let content: String
    let isDarkMode: Bool
    let horizontalPadding: CGFloat

    init(content: String, isDarkMode: Bool, horizontalPadding: CGFloat = 0) {
        self.content = content
        self.isDarkMode = isDarkMode
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        StructuredText(markdown: content)
            .textual.structuredTextStyle(.gitHub)
            .textual.highlighterTheme(.default)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, -16)
            .padding(.horizontal, horizontalPadding)
            .environment(\.colorScheme, isDarkMode ? .dark : .light)
    }
}

struct CollapsibleThinkingBox: View {
    let thinkingText: String
    let isDarkMode: Bool
    let isStreaming: Bool
    let generationTimeSeconds: Double?
    let thinkingSummary: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                if let seconds = generationTimeSeconds {
                    Text("Thought for \(String(format: "%.1f", seconds))s")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : Color.black.opacity(0.6))
                } else if isStreaming {
                    if let summary = thinkingSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(isDarkMode ? .white : Color.black.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .modifier(TextPulseAnimation())
                    } else {
                        HStack(spacing: 4) {
                            Text("Thinking")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white : Color.black.opacity(0.8))
                            InlineLoadingDotsView(isDarkMode: isDarkMode)
                        }
                        .modifier(TextPulseAnimation())
                    }
                } else {
                    Text("Thinking")
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white : Color.black.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
    }
}

struct ThoughtsSheetView: View {
    let thinkingText: String
    let thinkingChunks: [ThinkingChunk]
    let generationTimeSeconds: Double?
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss

    private var titleText: String {
        if let seconds = generationTimeSeconds {
            return "Thought for \(String(format: "%.1f", seconds))s"
        }
        return "Thoughts"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !thinkingChunks.isEmpty {
                        ForEach(thinkingChunks) { chunk in
                            ThinkingChunkView(chunk: chunk, isDarkMode: isDarkMode)
                                .equatable()
                        }
                    } else {
                        Text(thinkingText)
                            .font(.system(.body))
                            .foregroundColor(isDarkMode ? .white.opacity(0.9) : Color.black.opacity(0.8))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ThinkingChunkView: View, Equatable {
    let chunk: ThinkingChunk
    let isDarkMode: Bool

    static func == (lhs: ThinkingChunkView, rhs: ThinkingChunkView) -> Bool {
        if lhs.chunk.isComplete && rhs.chunk.isComplete {
            return lhs.chunk.id == rhs.chunk.id && lhs.isDarkMode == rhs.isDarkMode
        }
        return lhs.chunk.id == rhs.chunk.id &&
               lhs.chunk.content == rhs.chunk.content &&
               lhs.isDarkMode == rhs.isDarkMode
    }

    var body: some View {
        Text(chunk.content)
            .font(.system(.body))
            .foregroundColor(isDarkMode ? .white.opacity(0.9) : Color.black.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}

struct LoadingDotsView: View {    
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .modifier(PulsingAnimation(delay: 0.2 * Double(index)))
            }
        }
        .foregroundColor(isDarkMode ? .white : .black)
    }
}

struct InlineLoadingDotsView: View {
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 4, height: 4)
                    .modifier(PulsingAnimation(delay: 0.2 * Double(index)))
            }
        }
        .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color.black.opacity(0.7))
    }
}

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct PulsingAnimation: ViewModifier {
    let delay: Double
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.0 : 0.6)
            .opacity(isPulsing ? 1.0 : 0.3)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isPulsing
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPulsing = true
                }
            }
    }
}

struct TextPulseAnimation: ViewModifier {
    @State private var offset: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let shimmerWidth = geometry.size.width * 0.4
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.35),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerWidth)
                    .offset(x: offset * (geometry.size.width + shimmerWidth))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    offset = 1.0
                }
            }
    }
}

struct MessageActionsView: View {
    @EnvironmentObject var viewModel: SwiftChat.ChatViewModel
    
    var body: some View {
        EmptyView() // Placeholder - replace with actual content when needed
    }
}

/// A simplified code block view without syntax highlighting

struct ChunkedContentView: View, Equatable {
    let chunks: [ContentChunk]
    let isDarkMode: Bool
    let isStreaming: Bool

    static func == (lhs: ChunkedContentView, rhs: ChunkedContentView) -> Bool {
        lhs.chunks == rhs.chunks &&
        lhs.isDarkMode == rhs.isDarkMode &&
        lhs.isStreaming == rhs.isStreaming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(chunks) { chunk in
                ChunkView(chunk: chunk, isDarkMode: isDarkMode, isStreaming: isStreaming)
            }
        }
    }
}

struct ChunkView: View, Equatable {
    let chunk: ContentChunk
    let isDarkMode: Bool
    let isStreaming: Bool

    static func == (lhs: ChunkView, rhs: ChunkView) -> Bool {
        if lhs.chunk.isComplete && rhs.chunk.isComplete {
            return lhs.chunk.id == rhs.chunk.id && lhs.isDarkMode == rhs.isDarkMode
        }
        return lhs.chunk.id == rhs.chunk.id &&
               lhs.chunk.isComplete == rhs.chunk.isComplete &&
               lhs.chunk.content == rhs.chunk.content &&
               lhs.isDarkMode == rhs.isDarkMode &&
               lhs.isStreaming == rhs.isStreaming
    }

    var body: some View {
        if chunk.type == .table && isStreaming {
            GeneratingTableView(isDarkMode: isDarkMode)
        } else {
            LaTeXMarkdownView(
                content: chunk.content,
                isDarkMode: isDarkMode,
                isStreaming: chunk.isComplete ? false : isStreaming
            )
            .equatable()
        }
    }
}

struct GeneratingTableView: View {
    let isDarkMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("Generating table")
                .font(.subheadline.weight(.medium))
                .foregroundColor(isDarkMode ? .white : .black)
            InlineLoadingDotsView(isDarkMode: isDarkMode)
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.15), lineWidth: 1)
        )
    }
}

struct ErrorMessageView: View {
    let errorMessage: String
    let isDarkMode: Bool
    var isRequestError: Bool = false
    var onRegenerate: (() -> Void)? = nil

    private var accentColor: Color {
        isRequestError ? .red : .orange
    }

    private var isConnectionError: Bool {
        let msg = errorMessage.lowercased()
        return msg.contains("internet connection") || msg.contains("network") || msg.contains("connection was lost") || msg.contains("unable to connect")
    }

    private var headerIcon: String {
        if isConnectionError { return "wifi.exclamationmark" }
        return "exclamationmark.triangle"
    }

    private var headerText: String {
        if isConnectionError { return "Connection Lost" }
        return "Something Went Wrong"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: headerIcon)
                    .foregroundColor(accentColor)
                    .font(.system(size: 16))

                Text(headerText)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isDarkMode ? .white : .black)

                Spacer()
            }

            Text(errorMessage)
                .font(.caption)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                if let onRegenerate = onRegenerate {
                    Button(action: onRegenerate) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                            Text("Try again")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct UserMessageEditView: View {
    @Binding var content: String
    let isDarkMode: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    private var textColor: Color {
        isDarkMode ? .white : .black
    }

    private var secondaryTextColor: Color {
        isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)
    }

    private var buttonBackgroundColor: Color {
        isDarkMode ? .white.opacity(0.1) : .black.opacity(0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Messages below will be deleted and regenerated.")
                .font(.system(size: 12))
                .foregroundColor(secondaryTextColor)

            TextField("Edit message...", text: $content, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(textColor)
                .lineLimit(1...4)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                .onSubmit {
                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave()
                    }
                }

            HStack(spacing: 8) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(buttonBackgroundColor)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave()
                    }
                }) {
                    Text("Save")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Sources Button and Sheet

/// Button showing "Sources" with overlapping favicons
private struct SourcesButton: View {
    let sources: [WebSearchSource]
    let isDarkMode: Bool
    let action: () -> Void
    
    private var uniqueDomains: [String] {
        var seen = Set<String>()
        var domains: [String] = []
        for source in sources {
            let domain = getDomain(from: source.url)
            if !seen.contains(domain) {
                seen.insert(domain)
                domains.append(domain)
            }
            if domains.count >= 4 { break }
        }
        return domains
    }
    
    private func getDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    
    private func faviconUrl(for domain: String) -> String {
        "https://icons.duckduckgo.com/ip3/\(domain).ico"
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("Sources")
                    .font(.system(size: 13, weight: .medium))
                
                // Overlapping favicons
                HStack(spacing: -6) {
                    ForEach(Array(uniqueDomains.enumerated()), id: \.offset) { index, domain in
                        AsyncImage(url: URL(string: faviconUrl(for: domain))) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure, .empty:
                                Image(systemName: "globe")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 18, height: 18)
                        .background(isDarkMode ? Color.black : Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1))
                        .zIndex(Double(uniqueDomains.count - index))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isDarkMode ? .white : .black)
    }
}

/// Sheet view showing all sources
private struct SourcesSheetView: View {
    let sources: [WebSearchSource]
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    
    private func getDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    
    private func faviconUrl(for domain: String) -> String {
        "https://icons.duckduckgo.com/ip3/\(domain).ico"
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sources) { source in
                    Button {
                        if let url = URL(string: source.url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: faviconUrl(for: getDomain(from: source.url)))) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .failure, .empty:
                                    Image(systemName: "globe")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                    .lineLimit(2)
                                
                                Text(getDomain(from: source.url))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
