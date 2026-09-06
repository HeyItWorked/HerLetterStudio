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
        try speechHypothesesReplaceRatherThanDuplicate()
        try roundTripPreservesLetterAndReferences()
        try longLettersPaginateWithoutLosingText()
        try emptyLetterHasOnePrintablePage()
        try storagePreservesPreviousFileAfterFailedWrite()
        try rejectsFutureSchema()
        print("PASS: 6 core checks (dictation, Unicode/photos, pagination/PDF, empty page, atomic storage, schema)")
    }
    static func speechHypothesesReplaceRatherThanDuplicate() throws {
        let base = "Dear friend,\n\n"
        try expect(DictationText.merge(base: base, hypothesis: "I remember") == "Dear friend,\n\nI remember", "first partial")
        try expect(DictationText.merge(base: base, hypothesis: "I remember the sea.") == "Dear friend,\n\nI remember the sea.", "revised partial duplicates words")
        try expect(DictationText.merge(base: "Hello.", hypothesis: "It is me.") == "Hello. It is me.", "sentence spacing")
        try expect(DictationText.merge(base: base, hypothesis: "") == base, "empty hypothesis changes text")
    }
    static func roundTripPreservesLetterAndReferences() throws {
        var letter = LetterDocument()
        letter.text = "Chère Zoë,\n\nA memory 🌿 — yours."
        letter.recipient = "Zoë"
        letter.photos = [ReferencePhoto(data: Data([1, 2, 3]), caption: "Summer")]
        let decoded = try JSONDecoder().decode(LetterDocument.self, from: JSONEncoder().encode(letter))
        try expect(decoded == letter, "document round trip loses content")
    }
    @MainActor static func longLettersPaginateWithoutLosingText() throws {
        var letter = LetterDocument()
        letter.text = String(repeating: "Dear Zoë, the sea was quiet, and everything felt possible.\n\n", count: 80)
        for paper in Paper.allCases {
            for handwriting in Handwriting.allCases {
                letter.paper = paper
                letter.handwriting = handwriting
                let layout = LetterLayout(document: letter)
                try expect(layout.pages.count > 2, "long letter not paginated")
                let ranges = layout.pages.map(\.range)
                try expect(ranges.first?.location == 0, "missing beginning")
                try expect(ranges.last.map { $0.location + $0.length } == letter.text.utf16.count, "missing ending")
                for i in 1..<ranges.count {
                    try expect(ranges[i].location == ranges[i - 1].location + ranges[i - 1].length, "gap between pages")
                }
                guard let pdf = PDFDocument(data: layout.pdfData()) else { throw CheckFailure(description: "invalid PDF") }
                try expect(pdf.pageCount == layout.pages.count, "PDF page count differs")
                let width = pdf.page(at: 0)!.bounds(for: .mediaBox).width
                try expect(abs(width - paper.width) < 0.01, "wrong physical paper size")
                let extracted = (pdf.string ?? "").filter { !$0.isWhitespace }
                try expect(extracted == letter.text.filter { !$0.isWhitespace }, "PDF text does not match letter")
            }
        }
    }
    @MainActor static func emptyLetterHasOnePrintablePage() throws {
        let layout = LetterLayout(document: LetterDocument())
        try expect(layout.pages.count == 1, "empty letter page count")
        try expect(!layout.pdfData().isEmpty, "empty PDF data")
    }
    static func storagePreservesPreviousFileAfterFailedWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("saved.letter")
        let original = LetterDocument.example
        try DocumentStorage.save(original, to: url)
        var changed = original; changed.text = "Edited"
        do {
            try DocumentStorage.save(changed, to: directory.appendingPathComponent("missing/subfolder.letter"))
            throw CheckFailure(description: "write unexpectedly succeeded")
        } catch is CocoaError {}
        let loaded = try DocumentStorage.load(from: url)
        try expect(loaded == original, "prior saved file changed after failure")
    }
    static func rejectsFutureSchema() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).letter")
        defer { try? FileManager.default.removeItem(at: url) }
        var future = LetterDocument(); future.schemaVersion = 99
        try DocumentStorage.save(future, to: url)
        do {
            _ = try DocumentStorage.load(from: url)
            throw CheckFailure(description: "unsupported schema accepted")
        } catch is CocoaError {}
    }
}
