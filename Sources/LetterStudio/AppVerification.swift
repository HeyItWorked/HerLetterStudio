import AppKit
import LetterCore

enum VerificationFailure: Error { case failed(String) }

@MainActor enum AppVerification {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw VerificationFailure.failed(message) }
    }

    static func voiceEditing(directory: URL) async throws {
        let model = StudioModel(inMemory: true)
        model.document.text = "Dear Alex. The quiet sea was beautiful."
        for name in ["replace", "insert", "font", "undo", "tender", "ink"] {
            await model.toggleCommand(audioFileURL: directory.appendingPathComponent(name + ".aiff"))
            let deadline = Date().addingTimeInterval(30)
            while model.speech.state != .idle && Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
            try check(model.speech.state == .idle && model.speech.error == nil, "speech fixture failed for \(name)")
            await model.toggleCommand()
            switch name {
            case "replace": try check(model.document.text.contains("calm sea"), "spoken replacement: \(model.commandInput)")
            case "insert": try check(model.document.text.contains("calm blue sea"), "spoken insertion: \(model.commandInput)")
            case "font": try check(model.document.handwriting == .baskerville, "spoken font: \(model.commandInput)")
            case "tender": try check(model.document.expression == .tender, "spoken expression: \(model.commandInput)")
            case "ink": try check(model.document.ink == .oxblood, "spoken ink: \(model.commandInput)")
            default: try check(model.document.handwriting == .aurore, "spoken undo: \(model.commandInput)")
            }
            print("PASS: spoken edit — \(model.commandInput) → \(model.commandFeedback)")
        }
    }

    static func workflowRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LetterWorkflow-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = StudioModel(storageURL: directory)
        model.document.text = "An earlier version."
        model.document.stationery = .rose
        let id = model.document.id
        try check(model.keepDraft(name: "Original"), "draft save failed")
        model.updateTypedText("A revised version.")
        model.document.stationery = .blue
        try check(model.saveNow(), "revised letter save failed")
        let reopened = StudioModel(storageURL: directory)
        reopened.loadDrafts()
        try check(reopened.drafts.count == 1 && reopened.drafts[0].name == "Original", "draft not retained after reopening")
        await reopened.restoreDraft(reopened.drafts[0])
        try check(reopened.document.text == "An earlier version." && reopened.document.stationery == .rose, "draft restore lost content or materials")
        try check(reopened.drafts.count == 2, "restore did not preserve current version")
        await reopened.undoText()
        try check(reopened.document.text == "A revised version." && reopened.document.stationery == .blue, "restore undo incomplete")
        reopened.focusMode = true
        await reopened.edit()
        try check(!reopened.focusMode && reopened.panel == .writing, "editing remained hidden in focus mode")
        let original = reopened.document
        await reopened.duplicate(original)
        try check(reopened.document.id != id && reopened.document.text == original.text, "duplicate lost text or reused identity")
        let copy = reopened.document
        await reopened.removeLetter(copy)
        try check(reopened.trash.contains { $0.id == copy.id } && !reopened.library.contains { $0.id == copy.id }, "remove did not preserve recoverable letter")
        let again = StudioModel(storageURL: directory)
        try check(again.trash.contains { $0.id == copy.id }, "removed letter did not persist")
        again.recoverLetter(copy)
        try check(again.library.contains { $0.id == copy.id } && again.trash.isEmpty, "recovery failed")
        again.updateTypedText("Typing through the editor")
        await again.undoText()
        try check(again.document.text != "Typing through the editor", "typed edit absent from app undo")
        again.document.text = Array(repeating: "A long letter with many memories and details. ", count: 160).joined()
        try check(again.layout.pages.count >= 3, "long-letter fixture too short")
        await again.editPage(2)
        try check(again.showEditor && again.editorSelection == again.layout.pages[2].range, "page editor did not select the requested passage")
        // An unreadable draft history must never be replaced with an empty one.
        let draftFile = directory.appendingPathComponent("\(again.document.id).drafts")
        let damaged = Data("preserve these bytes".utf8)
        try damaged.write(to: draftFile)
        again.loadDrafts()
        try check(!again.keepDraft(), "corrupt draft history was overwritten")
        let remaining = try Data(contentsOf: draftFile)
        try check(remaining == damaged, "corrupt draft bytes changed")
        print("PASS: persistent drafts, full restore/undo, typing undo, duplicate, recoverable removal, corruption preservation, page editing and Focus")
    }

    static func run() async throws {
        try await workflowRecovery()

        let editor = StudioModel(inMemory: true)
        editor.document.text = "Dear Alex. The quiet sea was beautiful."
        await editor.applyVoiceEdit("replace quiet with calm")
        try check(editor.document.text == "Dear Alex. The calm sea was beautiful.", "voice replace did not apply")
        await editor.applyVoiceEdit("insert blue before sea")
        try check(editor.document.text.contains("calm blue sea"), "voice insertion did not apply")
        await editor.applyVoiceEdit("use Baskerville")
        try check(editor.document.handwriting == .baskerville && editor.layout.document.handwriting == .baskerville, "voice font did not reach page")
        await editor.undoText()
        try check(editor.document.handwriting == .aurore, "undo did not restore font")
        await editor.undoText()
        try check(editor.document.text == "Dear Alex. The calm sea was beautiful.", "multi-step undo lost edit")
        await editor.redoText()
        try check(editor.document.text.contains("calm blue sea"), "redo did not restore insertion")
        await editor.applyVoiceEdit("delete the last sentence")
        try check(editor.document.text == "Dear Alex.", "voice sentence deletion")
        await editor.undoText()
        try check(editor.document.text.contains("calm blue sea"), "destructive edit not undoable")
        await editor.applyVoiceEdit("replace missing with something")
        try check(editor.document.text.contains("calm blue sea") && editor.commandFeedback.contains("No edit"), "failed edit changed document or lacked feedback")
        await editor.applyVoiceEdit("set font size to 22")
        try check(editor.document.fontSize == 22, "voice size did not apply")
        await editor.undoText()
        editor.chooseFontSize(28)
        try check(!editor.canRedo, "manual font size did not invalidate stale redo")
        editor.fontSizeDrag(true)
        editor.chooseFontSize(25)
        editor.chooseFontSize(24)
        editor.fontSizeDrag(false)
        await editor.undoText()
        try check(editor.document.fontSize == 28, "slider drag should undo as one change")
        await editor.newLetter()
        try check(!editor.canUndo && !editor.canRedo && editor.commandInput.isEmpty, "new letter inherited edit history")
        print("PASS: voice editing, font selection, multi-step undo/redo, feedback, history isolation")
        let expressive = StudioModel(inMemory: true)
        let original = expressive.document
        await expressive.applyVoiceEdit("Less formal")
        try check(expressive.document.handwriting == .caveat && expressive.layout.document.expression == .familiar, "expression did not reach renderer")
        await expressive.applyVoiceEdit("Use oxblood")
        expressive.fontSizeDrag(true)
        expressive.chooseResonance(0.2)
        expressive.chooseResonance(1)
        expressive.fontSizeDrag(false)
        try check(expressive.document.text == original.text, "expression changed the author's words")
        await expressive.undoText()
        try check(expressive.document.resonance == nil, "resonance drag did not undo as one change")
        await expressive.undoText()
        try check(expressive.document.ink == original.ink, "ink undo failed")
        await expressive.undoText()
        try check(expressive.document == original, "expression undo did not restore the complete letter")
        await expressive.redoText()
        try check(expressive.document.expression == .familiar, "expression redo failed")
        expressive.resetExpression()
        try check(expressive.layout.document.expression == nil, "reset left stale layout")
        await expressive.applyVoiceEdit("Send to the writing desk")
        try check(expressive.showPrint, "writing desk did not open review")
        print("PASS: expression and ink commands, grouped resonance undo, reset, renderer synchronization, print review")
        let suiteName = "LetterStudio-QA-\(UUID())"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = StudioModel(inMemory: true, preferencesStore: suite)
        settings.toggleFavorite(.sacramento)
        settings.quietMode = true
        let settingsReopened = StudioModel(inMemory: true, preferencesStore: suite)
        try check(settingsReopened.favoriteHands.contains(.sacramento) && settingsReopened.quietMode, "writing preferences did not persist")
        expressive.chooseMaterial(.laid)
        try check(expressive.layout.document.material == .laid, "paper material did not reach screen")
        await expressive.undoText()
        try check(expressive.document.material == nil, "paper material undo failed")
        expressive.toggleFavorite(.parisienne)
        try check(expressive.favoriteHands.contains(.parisienne), "favorite was not added")
        expressive.toggleFavorite(.parisienne)
        try check(!expressive.favoriteHands.contains(.parisienne), "favorite was not removed")
        expressive.quietMode = true
        await expressive.replay()
        try check(!expressive.isReplaying && expressive.visibleCharacters == nil, "quiet mode animated replay")
        expressive.receiveDictation("A quiet letter.")
        try check(expressive.visibleCharacters == nil && expressive.document.text == "A quiet letter.", "quiet dictation did not update immediately")
        print("PASS: material rendering/undo, favorite toggle, quiet replay and dictation")
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
        let previousID = model.document.id
        await model.openWalkthrough()
        try check(model.document.id != previousID && model.document.photos.count == 2, "walkthrough did not create a complete new letter")
        try check(model.library.contains { $0.id == previousID }, "walkthrough replaced the previous letter")
        try check(model.walkthroughID == model.document.id && model.panel == .context, "walkthrough context not active")
        await model.applyVoiceEdit("Replace ordinary with beautiful")
        try check(model.document.text.contains("beautiful things"), "walkthrough edit example failed")
        print("PASS: walkthrough creates a saved photo letter, preserves prior work, and accepts its example edit")
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
