//
//  MessageInputView.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import UIKit
import PhotosUI

/// Input area for typing messages, including attachments and send button
struct MessageInputView: View {
    // MARK: - Constants
    fileprivate enum Layout {
        static let defaultHeight: CGFloat = 72
        static let minimumHeight: CGFloat = 72
        static let maximumHeight: CGFloat = 180
    }

    @Binding var messageText: String
    @ObservedObject var viewModel: SwiftChat.ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var textHeight: CGFloat = Layout.defaultHeight
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var audioService = AudioRecordingService.shared
    var isKeyboardVisible: Bool = false

    private var isDarkMode: Bool { colorScheme == .dark }

    // Attachment picker state
    @State private var showAddSheet = false
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingPickerAction: PickerAction?

    private enum PickerAction {
        case camera, photos, files
    }

    private var showAttachmentError: Binding<Bool> {
        Binding(
            get: { viewModel.attachmentError != nil },
            set: { if !$0 { viewModel.attachmentError = nil } }
        )
    }

    @ViewBuilder
    var body: some View {
        inputContent
            .alert("Attachment Error", isPresented: showAttachmentError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.attachmentError ?? "An error occurred")
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url, fileName in
                    viewModel.addDocumentAttachment(url: url, fileName: fileName)
                }
            }
            .sheet(isPresented: $showPhotoPicker, onDismiss: processSelectedPhotos) {
                NavigationStack {
                    PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                        Text("Select Photos")
                    }
                    .photosPickerStyle(.inline)
                    .navigationTitle("Select Photos")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showPhotoPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    if let data = image.jpegData(compressionQuality: CGFloat(Constants.Attachments.imageCompressionQuality)) {
                        viewModel.addImageAttachment(data: data, fileName: "Camera Photo.jpg")
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showAddSheet, onDismiss: {
                guard let action = pendingPickerAction else { return }
                pendingPickerAction = nil
                switch action {
                case .camera: showCamera = true
                case .photos: showPhotoPicker = true
                case .files: showDocumentPicker = true
                }
            }) {
                AddToSheetView(
                    viewModel: viewModel,
                    isDarkMode: isDarkMode,
                    onCamera: {
                        pendingPickerAction = .camera
                        showAddSheet = false
                    },
                    onPhotos: {
                        pendingPickerAction = .photos
                        showAddSheet = false
                    },
                    onFiles: {
                        pendingPickerAction = .files
                        showAddSheet = false
                    }
                )
                .presentationDetents([.height(340)])
                .presentationBackground(isDarkMode ? Color(hex: "161616") : Color(UIColor.systemGroupedBackground))
            }
    }

    @ViewBuilder
    private var inputContent: some View {
        if #available(iOS 26, *) {
            VStack(spacing: 4) {
                VStack(spacing: 0) {
                    if !viewModel.pendingAttachments.isEmpty {
                        AttachmentPreviewBar(
                            attachments: viewModel.pendingAttachments,
                            thumbnails: viewModel.pendingImageThumbnails,
                            onRemove: { id in viewModel.removePendingAttachment(id: id) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }

                    CustomTextEditor(text: $messageText,
                                     textHeight: $textHeight,
                                     placeholderText: viewModel.currentChat?.messages.isEmpty ?? true ? "What's on your mind?" : "Message",
                                     shouldFocusInput: viewModel.shouldFocusInput,
                                     isLoading: viewModel.isLoading,
                                     onFocusHandled: { viewModel.shouldFocusInput = false },
                                     onSendMessage: { text in viewModel.sendMessage(text: text) })
                        .frame(height: textHeight)
                        .padding(.horizontal)

                    HStack {
                        attachButton
                        webSearchButton
                        Spacer()

                        micButton

                        Button(action: sendOrCancelMessage) {
                            Image(systemName: viewModel.isLoading ? "stop.fill" : "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 24, height: 24)
                                .foregroundColor(isDarkMode ? Color.sendButtonForegroundDark : Color.sendButtonForegroundLight)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .clipShape(.circle)
                        .tint(isDarkMode ? Color.sendButtonBackgroundDark : Color.sendButtonBackgroundLight)
                        .padding(.trailing, 8)
                    }
                    .padding(.vertical, 8)
                }
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, isKeyboardVisible ? 12 : 0)
        } else {
            VStack(spacing: 4) {
                VStack(spacing: 0) {
                    if !viewModel.pendingAttachments.isEmpty {
                        AttachmentPreviewBar(
                            attachments: viewModel.pendingAttachments,
                            thumbnails: viewModel.pendingImageThumbnails,
                            onRemove: { id in viewModel.removePendingAttachment(id: id) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }

                    CustomTextEditor(text: $messageText,
                                     textHeight: $textHeight,
                                     placeholderText: viewModel.currentChat?.messages.isEmpty ?? true ? "What's on your mind?" : "Message",
                                     shouldFocusInput: viewModel.shouldFocusInput,
                                     isLoading: viewModel.isLoading,
                                     onFocusHandled: { viewModel.shouldFocusInput = false },
                                     onSendMessage: { text in viewModel.sendMessage(text: text) })
                        .frame(height: textHeight)
                        .padding(.horizontal)

                    HStack {
                        attachButton
                        webSearchButton
                        Spacer()

                        micButton

                        Button(action: sendOrCancelMessage) {
                            ZStack {
                                Circle()
                                    .fill(isDarkMode ? Color.sendButtonBackgroundDark : Color.sendButtonBackgroundLight)
                                    .frame(width: 32, height: 32)
                                Image(systemName: viewModel.isLoading ? "stop.fill" : "arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isDarkMode ? Color.sendButtonForegroundDark : Color.sendButtonForegroundLight)
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    .padding(.vertical, 8)
                }
                .background {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(.thickMaterial)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, isKeyboardVisible ? 12 : 0)
        }
    }

    @ViewBuilder
    private var attachButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
        }
        .disabled(viewModel.isLoading || viewModel.isProcessingAttachment)
        .padding(.leading, 8)
    }

    @ViewBuilder
    private var webSearchButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isWebSearchEnabled.toggle()
                settings.webSearchEnabled = viewModel.isWebSearchEnabled
            }
        }) {
            if viewModel.isWebSearchEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Web Search")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
                .foregroundColor(.blue)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.leading, 8)
    }

    @State private var isPulsing = false

    @ViewBuilder
    private var micButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                if audioService.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                }

                Group {
                    if audioService.isTranscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 20))
                    }
                }
                .frame(width: 32, height: 32)
                .foregroundColor(audioService.isRecording ? .red : .secondary)
            }
            .frame(width: 32, height: 32)
        }
        .onChange(of: audioService.isRecording) { _, isRecording in
            isPulsing = isRecording
        }
        .disabled(audioService.isTranscribing || viewModel.isLoading)
        .padding(.trailing, 4)
    }

    private func toggleRecording() {
        if audioService.isRecording {
            guard let fileURL = audioService.stopRecording() else { return }
            Task {
                do {
                    let client = AppConfig.shared.makeClient()
                    let text = try await audioService.transcribe(fileURL: fileURL, client: client)
                    messageText += (messageText.isEmpty ? "" : " ") + text
                } catch {
                    viewModel.attachmentError = error.localizedDescription
                }
            }
        } else {
            Task {
                let granted = await audioService.requestPermission()
                guard granted else {
                    viewModel.attachmentError = "Microphone access is required for voice input. Enable it in Settings."
                    return
                }
                do {
                    try audioService.startRecording()
                } catch {
                    viewModel.attachmentError = "Failed to start recording: \(error.localizedDescription)"
                }
            }
        }
    }

    private func sendOrCancelMessage() {
        if viewModel.isLoading {
            viewModel.cancelGeneration()
        } else if !messageText.isEmpty || !viewModel.pendingAttachments.isEmpty {
            viewModel.sendMessage(text: messageText)
            messageText = ""
            textHeight = Layout.defaultHeight
        }
    }

    private func processSelectedPhotos() {
        let items = selectedPhotoItems
        selectedPhotoItems = []
        for (index, item) in items.enumerated() {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let fileName = items.count > 1 ? "Photo \(index + 1).jpg" : "Photo.jpg"
                    viewModel.addImageAttachment(data: data, fileName: fileName)
                }
            }
        }
    }
}

/// Bottom sheet presented from the "+" button with attachment options and model selector
struct AddToSheetView: View {
    @ObservedObject var viewModel: SwiftChat.ChatViewModel
    let isDarkMode: Bool
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onFiles: () -> Void
    @Environment(\.dismiss) private var dismiss
    private var availableModels: [ModelType] {
        AppConfig.shared.filteredModelTypes()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Attachment buttons
                HStack(spacing: 12) {
                    if viewModel.currentModel.isMultimodal {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            attachmentButton(icon: "camera", label: "Camera") { onCamera() }
                        }
                        attachmentButton(icon: "photo.on.rectangle", label: "Photos") { onPhotos() }
                    }
                    attachmentButton(icon: "doc.badge.arrow.up", label: "Files") { onFiles() }
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Model selector
                Text("Select a Model")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, -12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(availableModels) { model in
                            ModelCard(
                                model: model,
                                isSelected: viewModel.currentModel.id == model.id,
                                isDarkMode: isDarkMode
                            ) {
                                viewModel.changeModel(to: model)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background((isDarkMode ? Color(hex: "161616") : Color(UIColor.systemGroupedBackground)).ignoresSafeArea())
            .navigationTitle("Add to Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

/// Simple model card for the model selector
struct ModelCard: View {
    let model: ModelType
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(model.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)

                Text(model.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .frame(width: 120, height: 110)
            .background(
                ZStack {
                    if #available(iOS 26, *) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thickMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.chatSurface(isDarkMode: isDarkMode))
                    }
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentPrimary.opacity(0.15))
                    }
                    if !isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    }
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.accentPrimary)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

/// Custom UIViewRepresentable for a properly managed text editor
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var textHeight: CGFloat
    var placeholderText: String
    var shouldFocusInput: Bool
    var isLoading: Bool
    var onFocusHandled: () -> Void
    var onSendMessage: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.alwaysBounceVertical = false
        textView.scrollsToTop = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 2, bottom: 8, right: 5)
        textView.textContainer.lineFragmentPadding = 0
        textView.tintColor = UIColor.systemBlue

        if text.isEmpty {
            textView.text = placeholderText
            textView.textColor = .lightGray
        } else {
            textView.text = text
            textView.textColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? .white : .black
            }
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        let isCurrentlyEditing = context.coordinator.isEditing

        if shouldFocusInput && !context.coordinator.hasFocusedFromFlag {
            context.coordinator.hasFocusedFromFlag = true
            DispatchQueue.main.async {
                if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
                self.onFocusHandled()
            }
        } else if !shouldFocusInput {
            context.coordinator.hasFocusedFromFlag = false
        }

        if text.isEmpty && !isCurrentlyEditing && uiView.textColor != .lightGray {
            uiView.text = placeholderText
            uiView.textColor = .lightGray
        } else if text.isEmpty && isCurrentlyEditing {
            if uiView.text.isEmpty && uiView.textColor == .lightGray {
                uiView.text = ""
                uiView.textColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .white : .black }
            } else if !uiView.text.isEmpty && uiView.textColor != .lightGray {
                self.text = uiView.text
            }
        } else if !text.isEmpty && uiView.textColor == .lightGray {
            uiView.text = text
            uiView.textColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .white : .black }
        } else if !text.isEmpty && uiView.text != text && uiView.textColor != .lightGray {
            uiView.text = text
        }

        uiView.isEditable = true

        let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: CGFloat.greatestFiniteMagnitude))
        let newHeight = min(MessageInputView.Layout.maximumHeight, max(MessageInputView.Layout.minimumHeight, size.height))
        if textHeight != newHeight {
            DispatchQueue.main.async { self.textHeight = newHeight }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        var isEditing = false
        var hasFocusedFromFlag = false

        init(_ parent: CustomTextEditor) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                let isMac = ProcessInfo.processInfo.isiOSAppOnMac
                if isMac {
                    let currentText = textView.text ?? ""
                    let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedText.isEmpty && !parent.isLoading {
                        parent.onSendMessage(trimmedText)
                        textView.text = ""
                        parent.text = ""
                        parent.textHeight = MessageInputView.Layout.defaultHeight
                        textView.text = parent.placeholderText
                        textView.textColor = .lightGray
                        textView.resignFirstResponder()
                    }
                    return false
                }
            }

            let currentText = textView.text as NSString
            let newText = currentText.replacingCharacters(in: range, with: text)
            if newText.isEmpty && isEditing { return true }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.textColor != .lightGray {
                parent.text = textView.text
                let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude))
                let newHeight = min(MessageInputView.Layout.maximumHeight, max(MessageInputView.Layout.minimumHeight, size.height))
                if parent.textHeight != newHeight { parent.textHeight = newHeight }
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            if textView.textColor == .lightGray {
                textView.text = ""
                textView.textColor = UIColor { tc in tc.userInterfaceStyle == .dark ? .white : .black }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            if textView.text.isEmpty {
                textView.text = parent.placeholderText
                textView.textColor = .lightGray
            }
        }
    }
}
