import Foundation

public enum Walkthrough {
    public static func letter() throws -> LetterDocument {
        var letter = LetterDocument()
        letter.title = "Twenty-eight ordinary years"
        letter.recipient = "Clara"
        letter.occasion = "28th wedding anniversary · from Daniel"
        letter.notes = "Client brief: warm, specific, no grand declarations. Recall the lake, the cold coffee, and choosing each other in ordinary moments. Fictional demonstration."
        letter.handwriting = .parisienne
        letter.expression = .tender
        letter.resonance = 0.35
        letter.ink = .sepia
        letter.fontSize = 25
        letter.text = "My dear Clara,\n\nTwenty-eight years, and I still think of that morning by the lake. We let the coffee go cold because neither of us wanted to leave.\n\nI thought happiness would announce itself. Instead, it became your keys by the door, two cups on the table, and the way you look up when I come home.\n\nThank you for making a life with me out of such ordinary things. Given all the mornings in the world, I would still choose ours.\n\nAll my love,\nDaniel"
        for (name, caption) in [("lake", "The morning we stayed · Luca Bravo / Unsplash"), ("coffee", "Two cups, no hurry · Nathan Dumlao / Unsplash")] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Walkthrough") else {
                throw CocoaError(.fileNoSuchFile)
            }
            letter.photos.append(ReferencePhoto(data: try Data(contentsOf: url), caption: caption))
        }
        return letter
    }
}
