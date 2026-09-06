import AppKit
import LetterCore

enum VerificationFailure: Error { case failed(String) }

@MainActor enum AppVerification {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw VerificationFailure.failed(message) }
    }

    static func run() async throws {
        let animation = StudioModel(inMemory: true)
        animation.document.text = ""
        animation.receiveDictation("dear Alex, I remember the afternoon by the water.")
        try await Task.sleep(for: .milliseconds(120))
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let before = animation.visibleCharacters ?? 0
            try check(before > 0 && before < 47, "ink did not reveal progressively")
            animation.receiveDictation("Dear Alex, I remember the afternoon by the water.")
            try check(animation.visibleCharacters == before, "capitalization correction rewound visible ink")
            animation.receiveDictation("Dear Alex, I remember the afternoon by the water. The light was warm.")
            try check(animation.visibleCharacters == before, "new hypothesis reset the reveal")
            try await Task.sleep(for: .milliseconds(25))
            let later = animation.visibleCharacters ?? 0
            try check(later > before && later != later.rounded(), "ink position is not continuous")
        }
        await animation.stopInput()
        animation.document.text = "A different draft."
        try await Task.sleep(for: .milliseconds(30))
        try check(animation.visibleCharacters == nil, "cancelled ink task affected the next draft")
        print("PASS: continuous ink, correction continuity, append continuity, cancellation")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("letter-check-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("library")
        let model = StudioModel(storageURL: directory)
        model.document.stationery = .blue
        try check(model.layout.document.stationery == .blue, "paper change did not reach renderer")
        model.document.title = "A new title"
        try check(model.layout.document.title == "A new title", "PDF title is stale")
        let stale = model.library[0]
        model.document.text = "The latest words must survive."
        await model.select(stale)
        try check(model.document.text == "The latest words must survive.", "selecting active letter lost pending edits")
        let reopened = StudioModel(storageURL: directory)
        try check(reopened.document.text == model.document.text, "reopened library differs")
        let savedID = model.document.id
        let backup = root.appendingPathComponent("disconnected-library")
        try FileManager.default.moveItem(at: directory, to: backup)
        try Data("Simulated unavailable volume".utf8).write(to: directory)
        model.document.text = "Keep this unsaved draft open."
        await model.newLetter()
        try check(model.document.id == savedID && model.document.text == "Keep this unsaved draft open.", "new letter discarded a failed save")
        try check(model.error != nil, "save error wasn't exposed")
        let canClose = await model.prepareToClose()
        try check(!canClose, "failed-save termination was permitted")
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: backup, to: directory)
        try check(model.saveNow(), "save did not recover after storage returned")
        let permission = PermissionGate()
        let speech = SpeechController(microphoneAccess: { await permission.wait() })
        let startup = Task { await speech.start { _ in } }
        while speech.state == .idle { await Task.yield() }
        await speech.stop()
        permission.resolve()
        await startup.value
        try check(speech.state == .idle, "cancelled microphone preparation restarted")
        print("PASS: app checks — paper/title updates, stale selection, reopen, failed-save navigation, recovery")
        print("PASS: cancelling permission wait leaves speech idle")
    }

    static func voice(file: URL, result: URL) async throws {
        let speech = SpeechController()
        var transcript = ""
        var hypotheses = 0
        await speech.start(audioFileURL: file) { text in transcript = text; hypotheses += 1 }
        let deadline = Date().addingTimeInterval(120)
        while speech.state != .idle && Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        try check(speech.state == .idle, "speech did not finish within 120 seconds")
        try check(speech.error == nil, speech.error ?? "speech error")
        try check(!transcript.isEmpty, "speech produced no words")
        let expected = "Dear Alex I remember the afternoon by the water The light was warm and the air was quiet Thank you for making the ordinary days feel special With love Liam"
        func words(_ text: String) -> [String] { text.lowercased().split { !$0.isLetter }.map(String.init) }
        try check(words(transcript) == words(expected), "known speech fixture words differ")
        try transcript.write(to: result, atomically: true, encoding: .utf8)
        print("PASS: speech file through live conversion and result pipeline — \(hypotheses) hypotheses; \(transcript)")
        // Stop twice while audio is still entering the live stream. No later result
        // may escape the stop boundary and overwrite a newly selected document.
        await speech.start(audioFileURL: file) { _ in hypotheses += 1 }
        try await Task.sleep(for: .milliseconds(70))
        async let first: Void = speech.stop()
        async let second: Void = speech.stop()
        _ = await (first, second)
        let stoppedCount = hypotheses
        try await Task.sleep(for: .milliseconds(300))
        try check(speech.state == .idle && stoppedCount == hypotheses, "results escaped concurrent stop boundary")
        print("PASS: concurrent stop drains speech results before returning")
    }

    static func microphone() async throws {
        let speech = SpeechController()
        await speech.start { _ in }
        try check(speech.state == .listening, speech.error ?? "Microphone did not start")
        try await Task.sleep(for: .seconds(3))
        await speech.stop()
        try check(speech.capturedBuffers > 0, "Microphone delivered no audio buffers")
        print("PASS: live microphone — \(speech.capturedBuffers) audio buffers captured and converted; stopped cleanly")
    }
}

@MainActor private final class PermissionGate {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var resolved = false
    func wait() async -> Bool {
        if resolved { return true }
        return await withCheckedContinuation { continuation = $0 }
    }
    func resolve() { resolved = true; continuation?.resume(returning: true); continuation = nil }
}
