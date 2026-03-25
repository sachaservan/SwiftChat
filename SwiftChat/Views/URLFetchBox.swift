//
//  URLFetchBox.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI

/// Inline row showing URL fetch count; tapping opens detail sheet
struct URLFetchBox: View {
    let urlFetches: [URLFetchState]
    let isDarkMode: Bool
    let onTap: () -> Void

    private var isFetching: Bool {
        urlFetches.contains { $0.status == .fetching }
    }

    private var completedCount: Int {
        urlFetches.filter { $0.status == .completed }.count
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                if isFetching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Reading \(urlFetches.count) link\(urlFetches.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(isDarkMode ? .white : .black.opacity(0.8))
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 13))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        Text("Read \(completedCount) link\(completedCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                        fetchFavicons
                    }
                }
                Spacer()
                if !isFetching {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
        .disabled(urlFetches.isEmpty)
    }

    @ViewBuilder
    private var fetchFavicons: some View {
        HStack(spacing: -4) {
            ForEach(Array(urlFetches.filter { $0.status == .completed }.prefix(4).enumerated()), id: \.element.id) { index, fetch in
                FaviconView(url: fetch.url, isDarkMode: isDarkMode)
                    .zIndex(Double(4 - index))
            }
            if completedCount > 4 {
                Text("+\(completedCount - 4)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .padding(.leading, 6)
            }
        }
    }
}

/// Sheet view showing all URL fetches with their status
struct URLFetchSheetView: View {
    let urlFetches: [URLFetchState]
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(urlFetches) { fetch in
                    URLFetchSheetRow(fetch: fetch, isDarkMode: isDarkMode)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A single row in the URL fetch sheet
private struct URLFetchSheetRow: View {
    let fetch: URLFetchState
    let isDarkMode: Bool

    private var displayHost: String {
        guard let urlObj = URL(string: fetch.url),
              let host = urlObj.host else { return fetch.url }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 10) {
                FaviconView(url: fetch.url, isDarkMode: isDarkMode)
                    .opacity(fetch.status == .failed || fetch.status == .blocked ? 0.4 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayHost)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black.opacity(0.85))
                        .lineLimit(1)

                    Text(statusLabel)
                        .font(.system(size: 12))
                        .foregroundColor(statusColor)
                }

                Spacer()

                if fetch.status == .completed {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(fetch.status != .completed)
    }

    private var statusLabel: String {
        switch fetch.status {
        case .fetching: return "Reading..."
        case .completed: return "Read"
        case .failed: return "Failed"
        case .blocked: return "Blocked"
        }
    }

    private var statusColor: Color {
        switch fetch.status {
        case .fetching: return isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)
        case .completed: return isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)
        case .failed: return .red.opacity(0.7)
        case .blocked: return .orange.opacity(0.7)
        }
    }

    private func openURL() {
        guard let url = URL(string: fetch.url),
              url.scheme == "https" || url.scheme == "http" else { return }
        UIApplication.shared.open(url)
    }
}
