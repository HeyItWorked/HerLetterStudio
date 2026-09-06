import Foundation

public enum VoiceCommand: Equatable, Sendable {
    case paragraph, undo, readBack, printPreview, replace(String, String)

    public static func parse(_ input: String) -> VoiceCommand? {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        switch command.lowercased() {
        case "new paragraph", "start a new paragraph": return .paragraph
        case "undo", "undo that": return .undo
        case "read back", "read it back", "read the letter": return .readBack
        case "print", "print the letter", "print preview": return .printPreview
        default: break
        }
        guard command.lowercased().hasPrefix("replace "),
              let separator = command.range(of: " with ", options: .caseInsensitive) else { return nil }
        let payloadStart = command.index(command.startIndex, offsetBy: 8)
        guard separator.lowerBound > payloadStart else { return nil }
        let old = String(command[payloadStart..<separator.lowerBound]).trimmingCharacters(in: .whitespaces)
        let new = String(command[separator.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !old.isEmpty, !new.isEmpty else { return nil }
        return .replace(old, new)
    }

    /// A replacement must identify exactly one phrase; ambiguity leaves text untouched.
    public static func replacing(_ old: String, with new: String, in text: String) -> String? {
        guard !old.isEmpty,
              let expression = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: old) + "(?![\\p{L}\\p{N}_])", options: .caseInsensitive) else { return nil }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard matches.count == 1, let range = Range(matches[0].range, in: text) else { return nil }
        var result = text
        result.replaceSubrange(range, with: new)
        return result
    }
}
