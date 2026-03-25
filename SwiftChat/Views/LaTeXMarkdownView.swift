//
//  LaTeXMarkdownView.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import Textual
import SwiftMath
import UIKit

private enum SegmentKind: Sendable {
    case markdown(String)
    case latex(String, isDisplay: Bool)
    case table(ParsedTable)
}



private struct ContentSegment: Sendable {
    let id: String
    let kind: SegmentKind
}

private struct SegmentView: View {
    let segment: ContentSegment
    let isDarkMode: Bool
    let isStreaming: Bool

    var body: some View {
        switch segment.kind {
        case .markdown(let text):
            // Strip citation markers from text - sources shown separately at message level
            // Skip during streaming to avoid catastrophic regex backtracking on incomplete citations
            let strippedText = isStreaming ? text : LaTeXMarkdownView.stripCitations(from: text)
            StructuredText(markdown: strippedText)
                .textual.structuredTextStyle(.gitHub)
                .textual.highlighterTheme(isStreaming ? .plain : .default)
                .textual.textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.colorScheme, isDarkMode ? .dark : .light)
        case .latex(let latex, let isDisplay):
            LaTeXView(
                latex: latex,
                isDisplay: isDisplay,
                isDarkMode: isDarkMode
            )
        case .table(let table):
            MarkdownTableView(
                table: table,
                isDarkMode: isDarkMode
            )
        }
    }
}

/// Simple cache for parsed markdown segments
private class MarkdownRenderCache: @unchecked Sendable {
    static let shared = MarkdownRenderCache()

    private var cache: [String: [ContentSegment]] = [:]
    private let queue = DispatchQueue(label: "com.swiftchat.markdown-cache", attributes: .concurrent)

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMemoryWarning() {
        clear()
    }

    func get(for key: String) -> [ContentSegment]? {
        queue.sync {
            cache[key]
        }
    }

    func set(_ segments: [ContentSegment], for key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = segments
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

/// A view that renders mixed Markdown and LaTeX content
struct LaTeXMarkdownView: View, Equatable {
    let content: String
    let isDarkMode: Bool
    let horizontalPadding: CGFloat
    let maxWidthAlignment: Alignment
    let isStreaming: Bool

    @State private var segments: [ContentSegment]? = nil

    // Pre-compiled regex patterns (compiled once, reused across all renders)
    private nonisolated(unsafe) static let codeBlockRegex = try? NSRegularExpression(pattern: "```[\\s\\S]*?```", options: [])
    private nonisolated(unsafe) static let inlineCodeRegex = try? NSRegularExpression(pattern: "`[^`]+`", options: [])
    private nonisolated(unsafe) static let displayLatexRegex = try? NSRegularExpression(pattern: "\\\\\\[(.+?)\\\\\\]", options: [.dotMatchesLineSeparators])
    private nonisolated(unsafe) static let inlineLatexRegex = try? NSRegularExpression(pattern: "\\\\\\((.+?)\\\\\\)", options: [])
    static func == (lhs: LaTeXMarkdownView, rhs: LaTeXMarkdownView) -> Bool {
        lhs.content == rhs.content &&
        lhs.isDarkMode == rhs.isDarkMode &&
        lhs.horizontalPadding == rhs.horizontalPadding &&
        lhs.maxWidthAlignment == rhs.maxWidthAlignment &&
        lhs.isStreaming == rhs.isStreaming
    }

    init(content: String, isDarkMode: Bool, horizontalPadding: CGFloat = 0, maxWidthAlignment: Alignment = .leading, isStreaming: Bool = false) {
        self.content = content
        self.isDarkMode = isDarkMode
        self.horizontalPadding = horizontalPadding
        self.maxWidthAlignment = maxWidthAlignment
        self.isStreaming = isStreaming

        // Resolve segments synchronously from cache when available so the
        // first render already has the final view tree. This prevents
        // UIHostingConfiguration from calculating the cell height based on
        // the fallback view and then never recalculating after the async
        // .task swaps in the parsed segments.
        if !isStreaming {
            let cacheKey = "\(content.hashValue)"
            if let cached = MarkdownRenderCache.shared.get(for: cacheKey) {
                _segments = State(initialValue: cached)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isStreaming {
                markdownFallback(content: content)
            } else if let segments = segments {
                ForEach(segments, id: \.id) { segment in
                    SegmentView(segment: segment, isDarkMode: isDarkMode, isStreaming: false)
                        .id(segment.id)
                }
            } else {
                markdownFallback(content: content)
            }
        }
        .environment(\.colorScheme, isDarkMode ? .dark : .light)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: horizontalPadding > 0 ? .infinity : nil, alignment: maxWidthAlignment)
        .transaction { transaction in
            transaction.animation = nil
        }
        .task(id: content) {
            guard !isStreaming else { return }
            let cacheKey = "\(content.hashValue)"
            if let cached = MarkdownRenderCache.shared.get(for: cacheKey) {
                if segments == nil {
                    segments = cached
                }
                return
            }
            let contentToProcess = content
            let parsed = Self.parseContent(contentToProcess)
            MarkdownRenderCache.shared.set(parsed, for: cacheKey)
            segments = parsed
        }
    }

    private func markdownFallback(content: String) -> some View {
        let strippedText = LaTeXMarkdownView.stripCitations(from: content)
        return StructuredText(markdown: strippedText)
            .textual.structuredTextStyle(.gitHub)
            .textual.highlighterTheme(isStreaming ? .plain : .default)
            .textual.textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, isDarkMode ? .dark : .light)
    }

    /// Strip citation markers from markdown text.
    /// Uses a linear-time scanner instead of regex to avoid catastrophic backtracking
    /// on incomplete citations during streaming.
    /// Matches: ` ?[N](#cite-N~...)`  where parens in URLs are balanced one level deep.
    static func stripCitations(from text: String) -> String {
        let chars = Array(text.unicodeScalars)
        let count = chars.count
        var result = String.UnicodeScalarView()
        result.reserveCapacity(count)
        var i = 0
        let citePrefix: [UnicodeScalar] = Array("#cite-".unicodeScalars)

        while i < count {
            // Check for optional leading space before `[`
            var start = i
            if chars[start] == " " && start + 1 < count && chars[start + 1] == "[" {
                start += 1
            }
            guard start < count, chars[start] == "[" else {
                result.append(chars[i])
                i += 1
                continue
            }

            // Match `[digits]`
            var j = start + 1
            guard j < count, chars[j] >= "0", chars[j] <= "9" else {
                result.append(chars[i])
                i += 1
                continue
            }
            let digitStart = j
            while j < count, chars[j] >= "0", chars[j] <= "9" { j += 1 }
            let digitEnd = j
            guard j < count, chars[j] == "]" else {
                result.append(chars[i])
                i += 1
                continue
            }
            j += 1

            // Match `(#cite-digits~`
            guard j < count, chars[j] == "(" else {
                result.append(chars[i])
                i += 1
                continue
            }
            j += 1
            var matches = true
            for c in citePrefix {
                guard j < count, chars[j] == c else { matches = false; break }
                j += 1
            }
            guard matches else {
                result.append(chars[i])
                i += 1
                continue
            }
            guard j < count, chars[j] >= "0", chars[j] <= "9" else {
                result.append(chars[i])
                i += 1
                continue
            }
            while j < count, chars[j] >= "0", chars[j] <= "9" { j += 1 }
            guard j < count, chars[j] == "~" else {
                result.append(chars[i])
                i += 1
                continue
            }
            j += 1

            // Capture URL (everything up to the next `~`)
            let urlStart = j
            var urlEnd = j
            var foundTilde = false
            while j < count {
                if chars[j] == "~" {
                    urlEnd = j
                    foundTilde = true
                    break
                }
                j += 1
            }

            guard foundTilde else {
                for k in i..<j {
                    result.append(chars[k])
                }
                i = j
                continue
            }
            j += 1

            // Scan past the title with balanced parens until closing `)`
            var depth = 1
            var found = false
            while j < count {
                if chars[j] == "(" {
                    depth += 1
                } else if chars[j] == ")" {
                    depth -= 1
                    if depth == 0 {
                        j += 1
                        found = true
                        break
                    }
                }
                j += 1
            }

            if found {
                // Convert citation to a markdown link: [domain](URL)
                var urlView = String.UnicodeScalarView()
                for k in urlStart..<urlEnd { urlView.append(chars[k]) }
                let url = String(urlView)
                let linkUrl = url.removingPercentEncoding ?? url
                let domain: String
                if let parsed = URL(string: linkUrl), let host = parsed.host {
                    domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                } else {
                    domain = linkUrl
                }
                for c in " [\(domain)](\(linkUrl))".unicodeScalars {
                    result.append(c)
                }
                i = j
            } else {
                for k in i..<j {
                    result.append(chars[k])
                }
                i = j
            }
        }

        return String(result)
    }

    /// Parse content into segments of markdown and LaTeX
    private nonisolated static func parseContent(_ content: String) -> [ContentSegment] {
        if content.count > Constants.Rendering.maxFullParsingCharacters {
            return [ContentSegment(id: "md_full_\(content.hashValue)", kind: .markdown(content))]
        }

        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)

        var excludedRanges: [NSRange] = []

        if let codeBlockRegex = Self.codeBlockRegex {
            let matches = codeBlockRegex.matches(in: content, options: [], range: fullRange)
            excludedRanges.append(contentsOf: matches.map(\.range))
        }

        if let inlineCodeRegex = Self.inlineCodeRegex {
            let matches = inlineCodeRegex.matches(in: content, options: [], range: fullRange)
            for match in matches where !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                excludedRanges.append(match.range)
            }
        }

        let tableSegments = Self.findMarkdownTables(in: content)
        excludedRanges.append(contentsOf: tableSegments.map(\.range))

        func isExcluded(_ range: NSRange) -> Bool {
            excludedRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }

        var latexRanges: [(range: NSRange, isDisplay: Bool)] = []

        if let displayRegex = Self.displayLatexRegex {
            let matches = displayRegex.matches(in: content, options: [], range: fullRange)
            for match in matches where !isExcluded(match.range) {
                latexRanges.append((match.range, true))
            }
        }

        if let inlineRegex = Self.inlineLatexRegex {
            let matches = inlineRegex.matches(in: content, options: [], range: fullRange)
            for match in matches where !isExcluded(match.range) {
                let overlaps = latexRanges.contains { existing in
                    NSLocationInRange(match.range.location, existing.range) ||
                    NSLocationInRange(existing.range.location, match.range)
                }
                if !overlaps {
                    latexRanges.append((match.range, false))
                }
            }
        }

        latexRanges.sort { $0.range.location < $1.range.location }

        var specialSegments: [SpecialSegment] = latexRanges.map { match in
            SpecialSegment(range: match.range, kind: .latex(isDisplay: match.isDisplay))
        }
        specialSegments.append(contentsOf: tableSegments.map { table in
            SpecialSegment(range: table.range, kind: .table(table.table))
        })
        specialSegments.sort { $0.range.location < $1.range.location }

        var segments: [ContentSegment] = []
        var lastIndex = content.startIndex

        for special in specialSegments {
            guard let swiftRange = Range(special.range, in: content) else { continue }

            if lastIndex < swiftRange.lowerBound {
                let markdownText = String(content[lastIndex..<swiftRange.lowerBound])
                if !markdownText.isEmpty {
                    segments.append(ContentSegment(
                        id: "md_\(special.range.location)_\(markdownText.hashValue)",
                        kind: .markdown(markdownText)
                    ))
                }
            }

            switch special.kind {
            case let .latex(isDisplay):
                let fullMatch = String(content[swiftRange])
                let latex: String

                if isDisplay {
                    if fullMatch.hasPrefix("\\[") && fullMatch.hasSuffix("\\]") {
                        latex = String(fullMatch.dropFirst(2).dropLast(2))
                    } else {
                        latex = fullMatch
                    }
                } else {
                    if fullMatch.hasPrefix("\\(") && fullMatch.hasSuffix("\\)") {
                        latex = String(fullMatch.dropFirst(2).dropLast(2))
                    } else {
                        latex = fullMatch
                    }
                }

                let sanitizedLatex = Self.sanitizeLatex(latex)

                segments.append(ContentSegment(
                    id: "latex_\(special.range.location)_\(sanitizedLatex.hashValue)",
                    kind: .latex(sanitizedLatex, isDisplay: isDisplay)
                ))
            case let .table(table):
                segments.append(ContentSegment(
                    id: "table_\(special.range.location)",
                    kind: .table(table)
                ))
            }

            lastIndex = swiftRange.upperBound
        }

        if lastIndex < content.endIndex {
            let remainingText = String(content[lastIndex...])
            if !remainingText.isEmpty {
                segments.append(ContentSegment(
                    id: "md_end_\(remainingText.hashValue)",
                    kind: .markdown(remainingText)
                ))
            }
        }

        if segments.isEmpty {
            segments.append(ContentSegment(
                id: "md_full_\(content.hashValue)",
                kind: .markdown(content)
            ))
        }

        segments = segments.flatMap { segment -> [ContentSegment] in
            guard case .markdown(let text) = segment.kind,
                  text.count > Constants.Rendering.maxMarkdownSegmentCharacters else {
                return [segment]
            }
            return splitMarkdownSegment(text, baseId: segment.id)
        }

        return segments
    }

    private nonisolated static func splitMarkdownSegment(_ text: String, baseId: String) -> [ContentSegment] {
        let paragraphs = text.components(separatedBy: "\n\n")
        var result: [ContentSegment] = []
        var current = ""
        var subIndex = 0

        for (_, paragraph) in paragraphs.enumerated() {
            let candidate = current.isEmpty ? paragraph : current + "\n\n" + paragraph
            if candidate.count > Constants.Rendering.maxMarkdownSegmentCharacters && !current.isEmpty {
                result.append(ContentSegment(
                    id: "\(baseId)_split_\(subIndex)",
                    kind: .markdown(current)
                ))
                subIndex += 1
                current = paragraph
            } else {
                current = candidate
            }
        }

        if !current.isEmpty {
            result.append(ContentSegment(
                id: "\(baseId)_split_\(subIndex)",
                kind: .markdown(current)
            ))
        }

        return result
    }

    private nonisolated static func sanitizeLatex(_ latex: String) -> String {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? latex : trimmed

        guard base.contains("\\text{") else { return base }

        return Self.normalizeTextCommands(in: base)
    }

    private nonisolated static func normalizeTextCommands(in latex: String) -> String {
        var result = ""
        var index = latex.startIndex

        while index < latex.endIndex {
            if latex[index...].hasPrefix("\\text{") {
                let contentStart = latex.index(index, offsetBy: 6)
                var cursor = contentStart
                var depth = 1

                while cursor < latex.endIndex && depth > 0 {
                    let character = latex[cursor]
                    if character == "{" {
                        depth += 1
                    } else if character == "}" {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    cursor = latex.index(after: cursor)
                }

                if depth == 0 {
                    let content = String(latex[contentStart..<cursor])
                    result += Self.rewriteTextContent(content)
                    index = latex.index(after: cursor)
                } else {
                    result += String(latex[index...])
                    break
                }
            } else {
                result.append(latex[index])
                index = latex.index(after: index)
            }
        }

        return result
    }

    private nonisolated static func rewriteTextContent(_ content: String) -> String {
        guard content.contains("\\(") else {
            return "\\text{\(content)}"
        }

        var result = ""
        var currentIndex = content.startIndex

        while let openRange = content.range(of: "\\(", range: currentIndex..<content.endIndex) {
            let textSegment = String(content[currentIndex..<openRange.lowerBound])
            if !textSegment.isEmpty {
                result += "\\text{\(textSegment)}"
            }

            let mathStart = openRange.upperBound
            guard let closeRange = content.range(of: "\\)", range: mathStart..<content.endIndex) else {
                let remainder = String(content[openRange.lowerBound..<content.endIndex])
                if !remainder.isEmpty {
                    result += "\\text{\(remainder)}"
                }
                return result
            }

            let mathContent = String(content[mathStart..<closeRange.lowerBound])
            result += mathContent
            currentIndex = closeRange.upperBound
        }

        let trailingText = String(content[currentIndex..<content.endIndex])
        if !trailingText.isEmpty {
            result += "\\text{\(trailingText)}"
        }

        return result
    }

    private struct SpecialSegment {
        let range: NSRange
        let kind: Kind

        enum Kind {
            case latex(isDisplay: Bool)
            case table(ParsedTable)
        }
    }

    private struct TableMatch {
        let range: NSRange
        let table: ParsedTable
    }

    private struct LineInfo {
        let text: String
        let enclosingRange: Range<String.Index>
    }

    private nonisolated static func findMarkdownTables(in content: String) -> [TableMatch] {
        guard content.contains("|") else { return [] }

        var lines: [LineInfo] = []
        content.enumerateSubstrings(in: content.startIndex..<content.endIndex, options: .byLines) { substring, _, enclosingRange, _ in
            let line = substring ?? ""
            lines.append(LineInfo(text: line, enclosingRange: enclosingRange))
        }

        var matches: [TableMatch] = []
        var index = 0

        while index < lines.count {
            let headerLine = lines[index].text.trimmingCharacters(in: .whitespaces)
            guard headerLine.hasPrefix("|") && headerLine.contains("|") else {
                index += 1
                continue
            }

            let alignmentIndex = index + 1
            guard alignmentIndex < lines.count else {
                index += 1
                continue
            }

            let alignmentLine = lines[alignmentIndex].text
            guard Self.isAlignmentLine(alignmentLine) else {
                index += 1
                continue
            }

            var collected = [lines[index].text, alignmentLine]
            var lastIndex = alignmentIndex
            var rowIndex = alignmentIndex + 1

            while rowIndex < lines.count {
                let candidate = lines[rowIndex].text.trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty { break }
                guard candidate.hasPrefix("|") && candidate.contains("|") else { break }
                collected.append(lines[rowIndex].text)
                lastIndex = rowIndex
                rowIndex += 1
            }

            if let parsed = Self.parseTable(lines: collected) {
                let lowerBound = lines[index].enclosingRange.lowerBound
                let upperBound = lines[lastIndex].enclosingRange.upperBound
                let range = NSRange(lowerBound..<upperBound, in: content)
                matches.append(TableMatch(range: range, table: parsed))
                index = lastIndex + 1
            } else {
                index += 1
            }
        }

        return matches
    }

    private nonisolated static func parseTable(lines: [String]) -> ParsedTable? {
        guard lines.count >= 2 else { return nil }

        let headerCells = parseTableCells(from: lines[0])
        let alignmentCells = parseAlignmentRow(from: lines[1], columnCount: headerCells.count)
        guard !headerCells.isEmpty else { return nil }

        let columnCount = max(headerCells.count, alignmentCells.count)
        let normalizedHeader = normalizeRow(headerCells, targetCount: columnCount)
        let normalizedAlignments = alignmentCells.count == columnCount ? alignmentCells : normalizeAlignments(alignmentCells, targetCount: columnCount)

        var rows: [[String]] = []
        for line in lines.dropFirst(2) {
            let cells = parseTableCells(from: line)
            rows.append(normalizeRow(cells, targetCount: columnCount))
        }

        return ParsedTable(headers: normalizedHeader, alignments: normalizedAlignments, rows: rows)
    }

    private nonisolated static func parseAlignmentRow(from line: String, columnCount: Int) -> [TableAlignment] {
        let cells = parseTableCells(from: line)
        guard !cells.isEmpty else { return Array(repeating: .leading, count: columnCount) }

        let alignments = cells.map { cell -> TableAlignment in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let leading = trimmed.hasPrefix(":")
            let trailing = trimmed.hasSuffix(":")

            switch (leading, trailing) {
            case (true, true):
                return .center
            case (false, true):
                return .trailing
            default:
                return .leading
            }
        }

        return normalizeAlignments(alignments, targetCount: max(columnCount, alignments.count))
    }

    private nonisolated static func normalizeAlignments(_ alignments: [TableAlignment], targetCount: Int) -> [TableAlignment] {
        if alignments.count == targetCount {
            return alignments
        } else if alignments.count < targetCount {
            return alignments + Array(repeating: .leading, count: targetCount - alignments.count)
        } else {
            return Array(alignments.prefix(targetCount))
        }
    }

    private nonisolated static func normalizeRow(_ cells: [String], targetCount: Int) -> [String] {
        if cells.count == targetCount {
            return cells
        } else if cells.count < targetCount {
            return cells + Array(repeating: "", count: targetCount - cells.count)
        } else {
            return Array(cells.prefix(targetCount))
        }
    }

    private nonisolated static func parseTableCells(from line: String) -> [String] {
        let placeholder = "__ESCAPED_PIPE__"
        var working = line.trimmingCharacters(in: .whitespaces)

        while working.hasPrefix("|") {
            working.removeFirst()
        }
        while working.hasSuffix("|") {
            working.removeLast()
        }

        working = working.replacingOccurrences(of: "\\|", with: placeholder)

        let parts = working.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        return parts.map { part in
            part.replacingOccurrences(of: placeholder, with: "|").trimmingCharacters(in: .whitespaces)
        }
    }

    private nonisolated static func isAlignmentLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") else { return false }

        let cells = parseTableCells(from: line)
        guard !cells.isEmpty else { return false }

        let allowed = CharacterSet(charactersIn: "-: ")
        return cells.allSatisfy { cell in
            let cellTrimmed = cell.trimmingCharacters(in: .whitespaces)
            guard cellTrimmed.contains("-") else { return false }
            return cellTrimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
    }
}

private struct ParsedTable: Sendable {
    let headers: [String]
    let alignments: [TableAlignment]
    let rows: [[String]]
}

private enum TableAlignment: Sendable {
    case leading
    case center
    case trailing

    var viewAlignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private struct MarkdownTableView: View {
    let table: ParsedTable
    let isDarkMode: Bool

    @State private var columnWidths: [Int: CGFloat] = [:]

    private var borderColor: SwiftUI.Color {
        isDarkMode ? SwiftUI.Color.white.opacity(0.2) : SwiftUI.Color.black.opacity(0.2)
    }

    private var headerBackground: SwiftUI.Color {
        SwiftUI.Color.clear
    }

    private var alternatingRowBackground: SwiftUI.Color {
        SwiftUI.Color.clear
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tableContainer
            ScrollView(.horizontal, showsIndicators: true) {
                tableContainer
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if columnWidths.isEmpty {
                columnWidths = Self.measureColumnWidths(for: table)
            }
        }
    }

    /// Measure column widths using text measurement instead of rendering a hidden table.
    private static func measureColumnWidths(for table: ParsedTable) -> [Int: CGFloat] {
        let font = UIFont.systemFont(ofSize: Constants.UI.tableFontSize)
        let boldFont = UIFont.boldSystemFont(ofSize: Constants.UI.tableFontSize)
        let horizontalPadding = Constants.UI.tableCellHorizontalPadding * 2
        var widths: [Int: CGFloat] = [:]

        for (index, header) in table.headers.enumerated() {
            let size = (header as NSString).size(withAttributes: [.font: boldFont])
            widths[index] = min(size.width + horizontalPadding, Constants.UI.tableMaxColumnWidth)
        }

        for row in table.rows {
            for (index, cell) in row.enumerated() {
                let size = (cell as NSString).size(withAttributes: [.font: font])
                let width = min(size.width + horizontalPadding, Constants.UI.tableMaxColumnWidth)
                widths[index] = max(widths[index] ?? 0, width)
            }
        }

        return widths
    }

    private var tableContainer: some View {
        VStack(spacing: 0) {
            if !table.headers.isEmpty {
                MarkdownTableRowView(
                    cells: table.headers,
                    alignments: table.alignments,
                    isHeader: true,
                    isDarkMode: isDarkMode,
                    borderColor: borderColor,
                    background: headerBackground,
                    columnWidths: columnWidths
                )
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
            }

            ForEach(table.rows.indices, id: \.self) { index in
                MarkdownTableRowView(
                    cells: table.rows[index],
                    alignments: table.alignments,
                    isHeader: false,
                    isDarkMode: isDarkMode,
                    borderColor: borderColor,
                    background: index.isMultiple(of: 2) ? alternatingRowBackground : SwiftUI.Color.clear,
                    columnWidths: columnWidths
                )

                if index < table.rows.count - 1 {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

private struct MarkdownTableRowView: View {
    let cells: [String]
    let alignments: [TableAlignment]
    let isHeader: Bool
    let isDarkMode: Bool
    let borderColor: SwiftUI.Color
    let background: SwiftUI.Color
    let columnWidths: [Int: CGFloat]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                MarkdownTableCell(
                    content: cells[index],
                    alignment: alignments.indices.contains(index) ? alignments[index] : .leading,
                    isHeader: isHeader,
                    isDarkMode: isDarkMode,
                    columnWidth: columnWidths[index],
                    background: background
                )
                .frame(maxHeight: .infinity, alignment: .top)

                if index < cells.count - 1 {
                    Rectangle()
                        .fill(borderColor)
                        .frame(width: 1)
                }
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity)
    }
}

private struct MarkdownTableCell: View {
    let content: String
    let alignment: TableAlignment
    let isHeader: Bool
    let isDarkMode: Bool
    let columnWidth: CGFloat?
    let background: SwiftUI.Color

    var body: some View {
        let cellContent = LaTeXMarkdownView(
            content: content.isEmpty ? " " : content,
            isDarkMode: isDarkMode,
            horizontalPadding: 0,
            maxWidthAlignment: alignment.viewAlignment
        )
        .padding(.vertical, isHeader ? 6 : 5)
        .padding(.horizontal, Constants.UI.tableCellHorizontalPadding)

        if let width = columnWidth {
            cellContent
                .frame(width: width, alignment: alignment.viewAlignment)
                .frame(maxHeight: .infinity)
                .background(background)
        } else {
            cellContent
                .frame(maxHeight: .infinity)
                .background(background)
        }
    }
}

/// A view that renders LaTeX equations using SwiftMath
struct LaTeXView: View {
    let latex: String
    let isDisplay: Bool
    let isDarkMode: Bool

    private var isUnsupportedEnvironment: Bool {
        latex.contains("\\begin{tabular}") ||
        latex.contains("\\begin{longtable}")
    }

    var body: some View {
        if isUnsupportedEnvironment {
            UnsupportedLaTeXView(isDarkMode: isDarkMode)
        } else if isDisplay {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MathView(
                        latex: latex,
                        displayMode: true,
                        isDarkMode: isDarkMode
                    )
                    .fixedSize()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            MathView(
                latex: latex,
                displayMode: false,
                isDarkMode: isDarkMode
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }
}

private struct UnsupportedLaTeXView: View {
    let isDarkMode: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("LaTeX table not supported on iOS")
                .font(.subheadline)
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}

/// Bridge to SwiftMath's MTMathUILabel
struct MathView: UIViewRepresentable {
    let latex: String
    let displayMode: Bool
    let isDarkMode: Bool
    
    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.latex = latex
        label.labelMode = displayMode ? .display : .text
        label.textColor = isDarkMode ? .white : .black.withAlphaComponent(0.8)
        label.fontSize = displayMode ? 18 : 16
        label.textAlignment = displayMode ? .center : .left
        label.backgroundColor = .clear
        label.isUserInteractionEnabled = true
        label.contentInsets = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.sizeToFit()
        return label
    }
    
    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        uiView.latex = latex
        uiView.labelMode = displayMode ? .display : .text
        uiView.textColor = isDarkMode ? .white : .black.withAlphaComponent(0.8)
        uiView.fontSize = displayMode ? 18 : 16
        uiView.textAlignment = displayMode ? .center : .left
        uiView.contentInsets = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        uiView.setContentCompressionResistancePriority(.required, for: .vertical)
        uiView.setContentHuggingPriority(.required, for: .vertical)
        uiView.sizeToFit()
    }
}


