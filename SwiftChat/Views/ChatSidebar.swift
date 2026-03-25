//
//  ChatSidebar.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import Combine

struct ChatSidebar: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isOpen: Bool
    @ObservedObject var viewModel: SwiftChat.ChatViewModel
    @State private var editingChatId: String? = nil
    @State private var editingTitle: String = ""
    @State private var deletingChatId: String? = nil
    @State private var showDeleteAlert: Bool = false

    // Timer to update relative time strings
    @State private var timeUpdateTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var currentTime = Date()

    private func relativeTimeString(from date: Date) -> String {
        let now = currentTime
        let difference = now.timeIntervalSince(date)

        if difference < 60 {
            return "Just now"
        } else if difference < 3600 {
            let minutes = Int(difference / 60)
            return "\(minutes)m ago"
        } else if difference < 86400 {
            let hours = Int(difference / 3600)
            return "\(hours)h ago"
        } else if difference < 604800 {
            let days = Int(difference / 86400)
            return "\(days)d ago"
        } else if difference < 2592000 {
            let weeks = Int(difference / 604800)
            return "\(weeks)w ago"
        } else {
            let months = Int(difference / 2592000)
            return "\(months)mo ago"
        }
    }

    var body: some View {
        sidebarContent
            .frame(width: 300)
            .background(colorScheme == .dark ? Color.sidebarBackground(for: colorScheme) : Color.white)
            .ignoresSafeArea(edges: .bottom)
            .onReceive(timeUpdateTimer) { _ in
                currentTime = Date()
            }
            .alert("Delete Chat", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    deletingChatId = nil
                }
                Button("Delete", role: .destructive) {
                    if let id = deletingChatId {
                        viewModel.deleteChat(id)
                        if viewModel.chats.isEmpty {
                            viewModel.createNewChat()
                        }
                    }
                    deletingChatId = nil
                }
            }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Chat History Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Chat History")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .overlay(
                Divider()
                    .background(Color.gray.opacity(0.3)),
                alignment: .bottom
            )

            // Chat List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.chats.enumerated()), id: \.element.id) { index, chat in
                        ChatListItem(
                            chat: chat,
                            isSelected: viewModel.currentChat?.id == chat.id,
                            isEditing: editingChatId == chat.id,
                            editingTitle: $editingTitle,
                            timeString: chat.isBlankChat ? "" : relativeTimeString(from: chat.createdAt),
                            onSelect: {
                                viewModel.selectChat(chat)
                            },
                            onEdit: {
                                if editingChatId == chat.id {
                                    viewModel.updateChatTitle(chat.id, newTitle: editingTitle)
                                    editingChatId = nil
                                } else {
                                    startEditing(chat)
                                }
                            },
                            onDelete: { confirmDelete(chat) },
                            showEditDelete: !chat.isBlankChat
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .applyAlwaysBounceIfAvailable()
            .frame(maxHeight: .infinity)

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func startEditing(_ chat: Chat) {
        editingChatId = chat.id
        editingTitle = chat.title
    }

    private func confirmDelete(_ chat: Chat) {
        deletingChatId = chat.id
        showDeleteAlert = true
    }
}

// MARK: - Helpers

private extension View {
    @ViewBuilder
    func applyAlwaysBounceIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollBounceBehavior(.always)
        } else {
            self
        }
    }
}

struct ChatListItem: View {
    let chat: Chat
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingTitle: String
    let timeString: String
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let showEditDelete: Bool

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if isEditing {
                        TextField("Chat Title", text: $editingTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.primary)
                            .onSubmit { onEdit() }

                        HStack(spacing: 12) {
                            Button(action: onEdit) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primary)
                            }
                            Button(action: { editingTitle = chat.title; onEdit() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.primary)
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            Text(chat.title)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            if chat.isBlankChat {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                            }

                            Spacer()
                        }

                        if isSelected && showEditDelete {
                            HStack(spacing: 12) {
                                Button(action: onEdit) {
                                    Image(systemName: "square.and.pencil")
                                        .foregroundColor(.gray)
                                }
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }

                if !isEditing {
                    if !timeString.isEmpty {
                        Text(timeString)
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text(" ")
                            .font(.caption)
                            .frame(height: 14)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(UIColor.secondarySystemBackground) : Color(UIColor.secondarySystemBackground).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
