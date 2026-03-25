//
//  AttachmentPreviewBar.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI

struct AttachmentPreviewBar: View {
    let attachments: [Attachment]
    let thumbnails: [String: String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPreviewChip(
                        attachment: attachment,
                        thumbnailBase64: thumbnails[attachment.id],
                        onRemove: { onRemove(attachment.id) }
                    )
                }
            }
        }
    }
}

private struct AttachmentPreviewChip: View {
    let attachment: Attachment
    let thumbnailBase64: String?
    let onRemove: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: 8) {
            thumbnailOrIcon
                .frame(width: Constants.Attachments.previewThumbnailSize,
                       height: Constants.Attachments.previewThumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(isDarkMode ? .white : .black)

                HStack(spacing: 4) {
                    if attachment.processingState == .processing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Processing...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else if attachment.processingState == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text("Failed")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    } else {
                        Text(formattedFileSize)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
        )
        .frame(maxWidth: Constants.Attachments.previewMaxWidth)
        .padding(.top, 6)
        .padding(.trailing, 6)
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnailOrIcon: some View {
        if attachment.type == .image, let base64 = thumbnailBase64,
           let data = Data(base64Encoded: base64),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var iconName: String {
        let ext = (attachment.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "html": return "globe"
        case "csv": return "tablecells"
        case "md": return "text.document"
        default: return "doc.text"
        }
    }

    private var formattedFileSize: String {
        let bytes = attachment.fileSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
    }
}
