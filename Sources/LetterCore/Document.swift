import Foundation

public enum Handwriting: String, Codable, CaseIterable, Sendable {
    case aurore, caveat, personal
    public var name: String {
        switch self { case .aurore: "Aurore"; case .caveat: "Everyday"; case .personal: "Daydream" }
    }
    public var fontName: String {
        switch self { case .aurore: "LaBelleAurore"; case .caveat: "Caveat-Regular"; case .personal: "NothingYouCouldDo" }
    }
    public var subtitle: String {
        switch self { case .aurore: "Flowing & intimate"; case .caveat: "Easy & familiar"; case .personal: "Open & unhurried" }
    }
}

public enum Stationery: String, Codable, CaseIterable, Sendable {
    case ivory, blue, white, rose
    public var name: String { rawValue.capitalized }
    public var hex: UInt32 {
        switch self { case .ivory: 0xF6F0DF; case .blue: 0xDEEBE8; case .white: 0xFAFAF6; case .rose: 0xF0E2DA }
    }
}

public enum Ink: String, Codable, CaseIterable, Sendable {
    case indigo, graphite, sepia
    public var hex: UInt32 {
        switch self { case .indigo: 0x344D75; case .graphite: 0x343D3C; case .sepia: 0x755348 }
    }
}

public enum Paper: String, Codable, CaseIterable, Sendable {
    case letter, a4
    public var name: String { self == .letter ? "US Letter" : "A4" }
    public var width: Double { self == .letter ? 612 : 595.276 }
    public var height: Double { self == .letter ? 792 : 841.89 }
}

public struct ReferencePhoto: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var data: Data
    public var caption: String
    public init(data: Data, caption: String) { self.data = data; self.caption = caption }
}

public struct LetterDocument: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var schemaVersion = 1
    public var title = "An unwritten letter"
    public var recipient = ""
    public var occasion = "Just because"
    public var notes = ""
    public var text = ""
    public var handwriting: Handwriting = .aurore
    public var fontSize: Double = 24
    public var stationery: Stationery = .ivory
    public var ink: Ink = .indigo
    public var paper: Paper = .letter
    public var photos: [ReferencePhoto] = []
    public var updatedAt = Date()
    public init() {}
    public var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }

    public static var example: LetterDocument {
        var letter = LetterDocument()
        letter.title = "The things we keep"
        letter.recipient = "Someone you love"
        letter.occasion = "A little appreciation"
        letter.notes = "The ordinary moments.\nThe places that stay with us.\nThe things we forget to say."
        letter.text = "Dear you,\n\nI was thinking about that afternoon by the water. We had nowhere to be, and for once, that felt like enough.\n\nI remember the light on the table. The way you laughed before you finished your story. How the whole day seemed to slow down, just a little.\n\nThere are so many things I mean to tell you. Mostly, this: I am glad we get to be here at the same time.\n\nWith love,\nMe"
        return letter
    }
}

public enum DictationText {
    public static func merge(base: String, hypothesis: String) -> String {
        guard !hypothesis.isEmpty else { return base }
        let separator = base.isEmpty || base.last?.isWhitespace == true ? "" : " "
        return base + separator + hypothesis
    }
}

public enum DocumentStorage {
    public static func save(_ document: LetterDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: url, options: .atomic)
    }
    public static func load(from url: URL) throws -> LetterDocument {
        let document = try JSONDecoder().decode(LetterDocument.self, from: Data(contentsOf: url))
        guard document.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        return document
    }
}
