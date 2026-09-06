import Foundation

public enum VoiceCommand: Equatable, Sendable {
    case paragraph, undo, redo, readBack, printPreview, replace(String, String)
    case delete(String), insert(String, String, before: Bool), lastSentence, lastParagraph
    case expression(HandExpression), ink(Ink), resonance(Double)
    case font(Handwriting), size(Double), larger, smaller

    public static func parse(_ input: String) -> VoiceCommand? {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        switch command.lowercased() {
        case "a little more tender", "more tender", "make it tender": return .expression(.tender)
        case "less formal", "more familiar": return .expression(.familiar)
        case "more reflective", "more wistful": return .expression(.reflective)
        case "more restrained": return .resonance(0)
        case "more expressive": return .resonance(1)
        case "send to the writing desk": return .printPreview
        case "new paragraph", "start a new paragraph": return .paragraph
        case "undo", "undo that", "undo the last change", "undo last change": return .undo
        case "redo", "redo that", "redo the last change": return .redo
        case "delete last sentence", "delete the last sentence", "remove the last sentence": return .lastSentence
        case "delete last paragraph", "delete the last paragraph", "remove the last paragraph": return .lastParagraph
        case "make it bigger", "larger text", "increase font size": return .larger
        case "make it smaller", "smaller text", "decrease font size": return .smaller
        case "read back", "read it back", "read the letter": return .readBack
        case "print", "print the letter", "print preview": return .printPreview
        default: break
        }
        for ink in Ink.allCases {
            let names = [ink.rawValue, ink.name.lowercased()] + (ink == .oxblood ? ["ox blood", "ox blood sincerity"] : [])
            for name in names {
                if ["use \(name)", "use \(name) ink", "change ink to \(name)", "change it to \(name)"].contains(command.lowercased()) { return .ink(ink) }
            }
        }
        for style in Handwriting.allCases {
            let aliases = [style.name.lowercased(), style.rawValue.lowercased()]
            for name in aliases {
                if ["use \(name)", "use \(name) font", "change font to \(name)", "change the font to \(name)", "switch to \(name)"].contains(command.lowercased()) {
                    return .font(style)
                }
            }
        }
        for prefix in ["set font size to ", "font size "] where command.lowercased().hasPrefix(prefix) {
            if let size = Double(command.dropFirst(prefix.count)), (18...32).contains(size) { return .size(size) }
            return nil
        }
        for (prefix, separator) in [("replace ", " with "), ("change ", " to ")] {
            if let parts = parts(command, prefix: prefix, separator: separator) { return .replace(parts.0, parts.1) }
        }
        for (separator, before) in [(" before ", true), (" after ", false)] {
            if let parts = parts(command, prefix: "insert ", separator: separator) { return .insert(parts.0, parts.1, before: before) }
        }
        for prefix in ["delete ", "remove "] where command.lowercased().hasPrefix(prefix) {
            let phrase = clean(String(command.dropFirst(prefix.count)))
            if !phrase.isEmpty { return .delete(phrase) }
        }
        return nil
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
    }

    private static func parts(_ input: String, prefix: String, separator: String) -> (String, String)? {
        guard input.lowercased().hasPrefix(prefix) else { return nil }
        let payload = String(input.dropFirst(prefix.count))
        guard let split = payload.range(of: separator, options: .caseInsensitive) else { return nil }
        let first = clean(String(payload[..<split.lowerBound]))
        let second = clean(String(payload[split.upperBound...]))
        return first.isEmpty || second.isEmpty ? nil : (first, second)
    }

    public func editing(_ text: String) -> String? {
        switch self {
        case let .replace(old, new): return Self.replacing(old, with: new, in: text)
        case let .delete(phrase):
            guard let range = Self.uniqueRange(phrase, in: text) else { return nil }
            var start = range.lowerBound
            var end = range.upperBound
            // Remove the adjoining space while preserving punctuation and paragraph breaks.
            if end < text.endIndex, text[end] == " " { end = text.index(after: end) }
            else if start > text.startIndex, text[text.index(before: start)] == " " { start = text.index(before: start) }
            var result = text
            result.removeSubrange(start..<end)
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .insert(words, phrase, before):
            guard let range = Self.uniqueRange(phrase, in: text) else { return nil }
            var result = text
            result.insert(contentsOf: before ? words + " " : " " + words, at: before ? range.lowerBound : range.upperBound)
            return result
        case .lastSentence:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var last: Range<String.Index>?
            trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { _, range, _, _ in last = range }
            guard let last else { return nil }
            return String(trimmed[..<last.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        case .lastParagraph:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let expression = try? NSRegularExpression(pattern: "(?>\\r\\n|[\\r\\n])[ \\t]*(?>\\r\\n|[\\r\\n])|\\u2029")
            let matches = expression?.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) ?? []
            guard let match = matches.last, let separator = Range(match.range, in: trimmed) else { return "" }
            return String(trimmed[..<separator.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        default: return nil
        }
    }

    /// A replacement must identify exactly one phrase; ambiguity leaves text untouched.
    public static func replacing(_ old: String, with new: String, in text: String) -> String? {
        guard let range = uniqueRange(old, in: text) else { return nil }
        var result = text
        result.replaceSubrange(range, with: new)
        return result
    }

    private static func uniqueRange(_ phrase: String, in text: String) -> Range<String.Index>? {
        guard !phrase.isEmpty,
              let expression = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: phrase) + "(?![\\p{L}\\p{N}_])", options: .caseInsensitive) else { return nil }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard matches.count == 1 else { return nil }
        return Range(matches[0].range, in: text)
    }
}
