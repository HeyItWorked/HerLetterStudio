import Foundation

public enum Handwriting: String, Codable, CaseIterable, Sendable {
    case aurore, caveat, personal, baskerville, georgia, palatino, typewriter, badscript, reenie, sacramento, parisienne
    public static var galleryOrder: [Handwriting] { [.badscript, .reenie, .sacramento, .parisienne] + allCases.filter { ![.badscript, .reenie, .sacramento, .parisienne].contains($0) } }
    public var name: String {
        switch self { case .aurore: "Aurore"; case .caveat: "Everyday"; case .personal: "Daydream"; case .baskerville: "Baskerville"; case .georgia: "Georgia"; case .palatino: "Palatino"; case .typewriter: "Typewriter"; case .badscript: "Bad Script"; case .reenie: "Reenie Beanie"; case .sacramento: "Sacramento"; case .parisienne: "Parisienne" }
    }
    public var fontName: String {
        switch self { case .aurore: "LaBelleAurore"; case .caveat: "Caveat-Regular"; case .personal: "NothingYouCouldDo"; case .baskerville: "Baskerville"; case .georgia: "Georgia"; case .palatino: "Palatino-Roman"; case .typewriter: "AmericanTypewriter"; case .badscript: "BadScript-Regular"; case .reenie: "ReenieBeanie"; case .sacramento: "Sacramento-Regular"; case .parisienne: "Parisienne-Regular" }
    }
    public var subtitle: String {
        switch self { case .aurore: "Flowing & intimate"; case .caveat: "Easy & familiar"; case .personal: "Open & unhurried"; case .baskerville: "Elegant correspondence"; case .georgia: "Warm & readable"; case .palatino: "Classic & literary"; case .typewriter: "A personal dispatch"; case .badscript: "Slanted & thoughtful"; case .reenie: "Loose & spontaneous"; case .sacramento: "Fine loops & quiet grace"; case .parisienne: "Flourished & romantic" }
    }
}

public extension Handwriting {
    func matches(_ query: String) -> Bool {
        let words = (name + " " + subtitle + " " + rawValue).lowercased()
        return query.lowercased().split(whereSeparator: \.isWhitespace).allSatisfy { words.contains($0) }
    }
}

public enum PaperMaterial: String, Codable, CaseIterable, Sendable {
    case cotton, laid, vellum, onion, bond
    public var name: String {
        switch self { case .cotton: "Cotton Rag"; case .laid: "Laid"; case .vellum: "Vellum"; case .onion: "Onion Skin"; case .bond: "Cream Bond" }
    }
    public var detail: String {
        switch self {
        case .cotton: "Soft fibers, an intimate letter"
        case .laid: "Fine horizontal lines, traditional correspondence"
        case .vellum: "A smooth, quiet surface"
        case .onion: "Delicate mottling, an airmail memory"
        case .bond: "A familiar, lightly textured sheet"
        }
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
    case indigo, graphite, sepia, midnight, oxblood
    public var hex: UInt32 {
        switch self { case .indigo: 0x344D75; case .graphite: 0x343D3C; case .sepia: 0x755348; case .midnight: 0x252B39; case .oxblood: 0x783C46 }
    }
}

public enum HandExpression: String, Codable, CaseIterable, Sendable {
    case tender, familiar, reflective
    public var name: String { rawValue.capitalized }
    public var font: Handwriting {
        switch self { case .tender: .aurore; case .familiar: .caveat; case .reflective: .personal }
    }
    public var description: String {
        switch self {
        case .tender: "Flowing lines, a little room to breathe."
        case .familiar: "Open, easy, as though you were here."
        case .reflective: "Unhurried words. Space for a memory."
        }
    }
    public var lineHeight: Double {
        switch self { case .tender: 1.58; case .familiar: 1.48; case .reflective: 1.68 }
    }
    public var pace: Double {
        switch self { case .tender: 0.85; case .familiar: 1.1; case .reflective: 0.7 }
    }
}

public extension Ink {
    var name: String {
        switch self {
        case .indigo: "Cedar Blue-Black"
        case .graphite: "Lampblack Tenderness"
        case .sepia: "Sepia Heart"
        case .midnight: "Midnight Iron-Gall"
        case .oxblood: "Oxblood Sincerity"
        }
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
    // Optional fields preserve decoding and appearance of pre-expression letters.
    public var expression: HandExpression?
    public var resonance: Double?
    public var effectiveResonance: Double {
        guard let resonance, resonance.isFinite else { return 0.5 }
        return min(1, max(0, resonance))
    }
    public var revealPace: Double {
        guard let expression else { return 1 }
        return expression.pace * (1.15 - effectiveResonance * 0.3)
    }
    public var material: PaperMaterial?
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
