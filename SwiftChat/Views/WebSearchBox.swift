//
//  WebSearchBox.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI

/// Inline row showing web search status; tapping opens sources sheet
struct WebSearchBox: View {
    let webSearchState: WebSearchState
    let isDarkMode: Bool
    let isStreaming: Bool
    let webSearchSummary: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                headerContent
                Spacer()
                if webSearchState.status != .searching && !webSearchState.sources.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
        .disabled(webSearchState.status == .searching || webSearchState.sources.isEmpty)
    }

    @ViewBuilder
    private var headerContent: some View {
        switch webSearchState.status {
        case .searching:
            HStack(spacing: 8) {
                SearchingDotsView(isDarkMode: isDarkMode)
                if let summary = webSearchSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white : .black.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let query = webSearchState.query {
                    Text("Searching: \(query)")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white : .black.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Searching the web...")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white : .black.opacity(0.8))
                }
            }

        case .completed:
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))

                if webSearchState.sources.isEmpty {
                    Text("Web search completed")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                } else {
                    Text("\(webSearchState.sources.count) source\(webSearchState.sources.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))

                    sourceFavicons
                }
            }

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                Text("Search failed")
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.8))
            }

        case .blocked:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text(webSearchState.reason ?? "Search blocked")
                    .font(.subheadline)
                    .foregroundColor(.orange.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private var sourceFavicons: some View {
        HStack(spacing: -4) {
            ForEach(Array(webSearchState.sources.prefix(4).enumerated()), id: \.element.id) { index, source in
                FaviconView(url: source.url, isDarkMode: isDarkMode)
                    .zIndex(Double(4 - index))
            }
            if webSearchState.sources.count > 4 {
                Text("+\(webSearchState.sources.count - 4)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .padding(.leading, 6)
            }
        }
    }

}

/// Animated dots for searching state
struct SearchingDotsView: View {
    let isDarkMode: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 5, height: 5)
                    .modifier(PulsingAnimation(delay: 0.15 * Double(index)))
            }
        }
        .foregroundColor(.blue)
    }
}

/// Favicon view that displays a website icon
struct FaviconView: View {
    let url: String
    let isDarkMode: Bool

    private var faviconURL: URL? {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    var body: some View {
        AsyncImage(url: faviconURL) { phase in
            switch phase {
            case .empty:
                placeholderIcon
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                placeholderIcon
            @unknown default:
                placeholderIcon
            }
        }
        .frame(width: 16, height: 16)
        .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var placeholderIcon: some View {
        Image(systemName: "globe")
            .font(.system(size: 10))
            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
    }
}

/// Row view for a single source
struct SourceRowView: View {
    let source: WebSearchSource
    let isDarkMode: Bool

    private var displayHost: String {
        guard let url = URL(string: source.url),
              let host = url.host else { return source.url }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 10) {
                FaviconView(url: source.url, isDarkMode: isDarkMode)

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(displayHost)
                        .font(.system(size: 11))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func openURL() {
        guard let url = URL(string: source.url) else { return }
        UIApplication.shared.open(url)
    }
}
