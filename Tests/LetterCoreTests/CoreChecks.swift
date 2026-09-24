import Foundation
import PDFKit
import LetterCore

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(description: message) }
}

@main struct CoreChecks {
    @MainActor static func main() throws {
        FontLibrary.register()
        try test1()
        try test2()
        try test3()
        print("PASS: 3 core checks")
    }
    // dictation + voice commands
    static func test1() throws {
        try expect(DictationText.merge(base: "Hello.", hypothesis: "It is me.") == "Hello. It is me.", "merge")
        try expect(VoiceCommand.parse("Replace the sea with the mountains.") == .replace("the sea", "the mountains"), "parse")
        try expect(VoiceCommand.replacing("sea", with: "mountains", in: "The sea was quiet.") == "The mountains was quiet.", "replace")
    }
    // save and load
    static func test2() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).letter")
        defer { try? FileManager.default.removeItem(at: url) }
        let letter = LetterDocument.example
        try DocumentStorage.save(letter, to: url)
        let loaded = try DocumentStorage.load(from: url)
        try expect(loaded == letter, "round trip")
    }
    // pdf
    @MainActor static func test3() throws {
        var letter = LetterDocument()
        letter.text = String(repeating: "Dear Zoë, the sea was quiet.\n\n", count: 80)
        let layout = LetterLayout(document: letter)
        let pdf = PDFDocument(data: layout.pdfData())
        try expect(layout.pages.count > 1 && pdf?.pageCount == layout.pages.count, "pages")
        try expect(pdf?.string?.filter { !$0.isWhitespace } == letter.text.filter { !$0.isWhitespace }, "pdf text")
    }
}
