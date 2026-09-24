import AppKit
import LetterCore

enum VerificationFailure: Error { case failed(String) }

// TODO add more tests later
@MainActor enum AppVerification {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw VerificationFailure.failed(message) }
    }
    static func run() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("letter-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = StudioModel(storageURL: dir)
        model.document.text = "Dear Alex. The quiet sea was beautiful."
        await model.applyVoiceEdit("replace quiet with calm")
        try check(model.document.text == "Dear Alex. The calm sea was beautiful.", "replace didnt work")
        await model.undoText()
        try check(model.document.text.contains("quiet sea"), "undo didnt work")
        try check(model.saveNow(), "save failed")
        let model2 = StudioModel(storageURL: dir)
        try check(model2.document.text == model.document.text, "reopen lost the text")
        print("PASS: test1")
    }
}
