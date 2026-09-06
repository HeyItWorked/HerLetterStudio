import AppKit
import Observation
import UniformTypeIdentifiers
import PDFKit
import AVFoundation
import LetterCore

@MainActor @Observable final class StudioModel {
    var document: LetterDocument {
        didSet {
            if document.text != oldValue.text || document.handwriting != oldValue.handwriting ||
                document.expression != oldValue.expression || document.resonance != oldValue.resonance ||
                document.fontSize != oldValue.fontSize || document.ink != oldValue.ink || document.paper != oldValue.paper || document.stationery != oldValue.stationery || document.title != oldValue.title {
                layout = LetterLayout(document: document)
            }
            scheduleSave()
        }
    }
    var layout: LetterLayout
    var library: [LetterDocument] = []
    var panel: Panel = .context
    var showLibrary = false
    var showPrint = false
    var showGuide = false
    var showWalkthrough = false
    var walkthroughID: UUID?
    var showFonts = false
    var commandInput = ""
    var commandFeedback = "Say what you want to change."
    var lastEditBefore = ""
    var lastEditAfter = ""
    var includePaperColor = false
    var error: String?
    var saveStatus = "Saved on this Mac"
    var focusMode = false
    var isReplaying = false
    var visibleCharacters: Double?
    var commandMode = false
    var commandTranscript = ""
    let speech = SpeechController()
    private struct Revision: Equatable {
        var text: String
        var font: Handwriting
        var size: Double
        var expression: HandExpression?
        var resonance: Double?
        var ink: Ink
    }
    private var undoStack: [Revision] = []
    private var redoStack: [Revision] = []
    private var resizingFont = false
    private var revision: Revision { Revision(text: document.text, font: document.handwriting, size: document.fontSize, expression: document.expression, resonance: document.resonance, ink: document.ink) }
    private var saveTask: Task<Void, Never>?
    private var replayTask: Task<Void, Never>?
    private var inkTask: Task<Void, Never>?
    private let storage: URL?
    private let speaker = AVSpeechSynthesizer()
    enum Panel: String, CaseIterable { case context = "Context", writing = "Writing", materials = "Expression", voice = "Voice Edit" }

    init(inMemory: Bool = false, storageURL: URL? = nil) {
        FontLibrary.register()
        storage = inMemory ? nil : storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Letter Studio", isDirectory: true)
        var loaded: [LetterDocument] = []
        var loadError: String?
        if let storage {
            do {
                try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
                let files = try FileManager.default.contentsOfDirectory(at: storage, includingPropertiesForKeys: nil)
                for file in files where file.pathExtension == "letter" {
                    do { loaded.append(try DocumentStorage.load(from: file)) }
                    catch { loadError = "A saved letter could not be opened. Its original file has been preserved in your library folder." }
                }
            } catch { loadError = "Your library could not be opened: \(error.localizedDescription)" }
        }
        loaded.sort { $0.updatedAt > $1.updatedAt }
        let first = loaded.first ?? .example
        document = first
        layout = LetterLayout(document: first)
        library = loaded.isEmpty ? [first] : loaded
        error = loadError
        if !inMemory && loadError == nil { saveNow() }
    }

    var canUndo: Bool { undoStack.contains { $0 != revision } }
    var canRedo: Bool { !redoStack.isEmpty }
    var isBusy: Bool { speech.state != .idle }

    func scheduleSave() {
        guard storage != nil else { return }
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            self?.saveNow()
        }
    }

    @discardableResult func saveNow() -> Bool {
        guard let storage else { return true }
        saveTask?.cancel()
        var saved = document
        saved.updatedAt = Date()
        do {
            try DocumentStorage.save(saved, to: storage.appendingPathComponent("\(saved.id).letter"))
            library.removeAll { $0.id == saved.id }
            library.insert(saved, at: 0)
            saveStatus = "Saved on this Mac"
            return true
        } catch {
            saveStatus = "Not saved"
            self.error = "Couldn't save this letter: \(error.localizedDescription). Use File → Export Letter to keep a copy."
            return false
        }
    }

    func openWalkthrough() async {
        await stopInput()
        guard saveNow() else { return }
        do {
            let sample = try Walkthrough.letter()
            document = sample
            clearHistory()
            walkthroughID = sample.id
            panel = .context
            showLibrary = false
            showWalkthrough = false
            saveNow()
        } catch { self.error = "The sample photographs could not be loaded." }
    }

    func newLetter() async {
        await stopInput()
        guard saveNow() else { return }
        document = LetterDocument()
        clearHistory()
        panel = .context
        showLibrary = false
        saveNow()
    }

    func select(_ letter: LetterDocument) async {
        await stopInput()
        guard saveNow() else { return }
        document = library.first(where: { $0.id == letter.id }) ?? letter
        clearHistory()
        showLibrary = false
    }

    func toggleDictation() async {
        if commandMode { await finishCommand(); return }
        if isBusy { await speech.stop(); return }
        stopReplay()
        speaker.stopSpeaking(at: .immediate)
        rememberRevision()
        let base = document.text
        let documentID = document.id
        await speech.start { [weak self] transcript in
            guard let self, self.document.id == documentID else { return }
            self.receiveDictation(DictationText.merge(base: base, hypothesis: transcript))
        }
    }

    func stopInput() async {
        commandMode = false
        commandTranscript = ""
        stopReplay()
        speaker.stopSpeaking(at: .immediate)
        await speech.stop()
        inkTask?.cancel()
        inkTask = nil
        visibleCharacters = nil
    }

    func prepareToClose() async -> Bool {
        await stopInput()
        return saveNow()
    }

    func toggleCommand(audioFileURL: URL? = nil) async {
        if commandMode { await finishCommand(); return }
        await stopInput()
        panel = .voice
        commandFeedback = "Listening for your edit…"
        commandMode = true
        commandTranscript = ""
        await speech.start(audioFileURL: audioFileURL) { [weak self] text in self?.commandTranscript = text }
        if speech.state == .idle { commandMode = false }
    }

    private func finishCommand() async {
        await speech.stop()
        guard commandMode else { return }
        let text = commandTranscript
        commandMode = false
        commandTranscript = ""
        commandInput = text
        await applyVoiceEdit(text)
    }

    func applyVoiceEdit(_ input: String) async {
        let documentID = document.id
        await stopInput()
        guard document.id == documentID else { return }
        guard let command = VoiceCommand.parse(input) else {
            commandFeedback = "I didn't recognize that edit. Try one of the examples below."
            return
        }
        let before = document.text
        switch command {
        case .undo: let available = canUndo; await undoText(); commandFeedback = available ? "Undid the last change." : "Nothing to undo yet."; return
        case .redo: let available = canRedo; await redoText(); commandFeedback = available ? "Restored the change." : "Nothing to redo yet."; return
        case .readBack: await readBack(); commandFeedback = "Reading your letter."; return
        case .printPreview: showPrint = true; commandFeedback = "Ready to review for print."; return
        case let .expression(style): chooseExpression(style); commandFeedback = "The hand is now \(style.name.lowercased()). Your words are unchanged."; return
        case let .ink(ink): chooseInk(ink); commandFeedback = "Ink changed to \(ink.name)."; return
        case let .resonance(value): chooseResonance(value); commandFeedback = "Expression is now \(value == 0 ? "restrained" : "expansive")."; return
        case let .font(style): chooseFont(style); commandFeedback = "Font changed to \(style.name)."; return
        case let .size(size): chooseFontSize(size)
        case .larger: chooseFontSize(document.fontSize + 2)
        case .smaller: chooseFontSize(document.fontSize - 2)
        case .paragraph:
            rememberRevision()
            document.text = document.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
        default:
            guard let updated = command.editing(document.text) else {
                commandFeedback = "No edit made. Use a phrase that appears exactly once, or check that there is text to remove."
                return
            }
            rememberRevision()
            document.text = updated
        }
        lastEditBefore = before
        lastEditAfter = document.text
        commandFeedback = "Applied: \(input)"
    }

    func chooseExpression(_ expression: HandExpression) {
        guard document.expression != expression || document.handwriting != expression.font else { return }
        rememberRevision()
        var updated = document
        updated.expression = expression
        updated.handwriting = expression.font
        document = updated
    }

    func chooseInk(_ ink: Ink) {
        guard document.ink != ink else { return }
        rememberRevision()
        document.ink = ink
    }

    func chooseResonance(_ value: Double) {
        guard value.isFinite else { return }
        let value = min(1, max(0, value))
        guard document.resonance != value || document.expression == nil else { return }
        if !resizingFont { rememberRevision() }
        var updated = document
        updated.expression = updated.expression ?? .tender
        updated.resonance = value
        document = updated
    }

    func resetExpression() {
        guard document.expression != nil else { return }
        rememberRevision()
        var updated = document
        updated.expression = nil
        updated.resonance = nil
        document = updated
    }

    func fontSizeDrag(_ editing: Bool) {
        if editing { rememberRevision() }
        resizingFont = editing
    }

    func chooseFontSize(_ value: Double) {
        let size = min(32, max(18, value))
        guard document.fontSize != size else { return }
        if !resizingFont { rememberRevision() }
        document.fontSize = size
    }

    func chooseFont(_ font: Handwriting) {
        guard document.handwriting != font else { return }
        rememberRevision()
        document.handwriting = font
    }

    private func rememberRevision(clearRedo: Bool = true) {
        if undoStack.last != revision { undoStack.append(revision) }
        if undoStack.count > 50 { undoStack.removeFirst() }
        if clearRedo { redoStack.removeAll() }
    }

    private func clearHistory() {
        resizingFont = false
        undoStack.removeAll(); redoStack.removeAll()
        lastEditBefore = ""; lastEditAfter = ""
        commandInput = ""; commandFeedback = "Say what you want to change."
    }

    private func restore(_ state: Revision) {
        lastEditBefore = document.text
        lastEditAfter = state.text
        document.text = state.text
        document.handwriting = state.font
        document.fontSize = state.size
        document.expression = state.expression
        document.resonance = state.resonance
        document.ink = state.ink
    }

    func updateTypedText(_ text: String) {
        guard text != document.text else { return }
        redoStack.removeAll()
        document.text = text
    }

    func receiveDictation(_ text: String) {
        guard text != document.text else { return }
        redoStack.removeAll()
        let previousCount = Double(document.text.utf16.count)
        let position = visibleCharacters ?? previousCount
        document.text = text
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            inkTask?.cancel(); inkTask = nil
            visibleCharacters = nil; return
        }
        // Speech often revises capitalization/punctuation at the start of a phrase.
        // Keep the pen's progress instead of erasing back to the first changed character.
        visibleCharacters = min(position, Double(text.utf16.count))
        guard inkTask == nil else { return }
        inkTask = Task { [weak self] in
            var last = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let elapsed = min(0.05, now - last)
                last = now
                let target = Double(self.document.text.utf16.count)
                let position = self.visibleCharacters ?? target
                let speed = min(120.0, max(32.0, (target - position) * 2.5))
                self.visibleCharacters = min(target, position + elapsed * speed * self.document.revealPace)
                if self.visibleCharacters == target { break }
            }
            self?.visibleCharacters = nil
            self?.inkTask = nil
        }
    }

    func edit() async {
        await stopInput()
        rememberRevision(clearRedo: false)
        panel = .writing
    }

    func undoText() async {
        let documentID = document.id
        await stopInput()
        guard document.id == documentID else { return }
        while let previous = undoStack.popLast() {
            guard previous != revision else { continue }
            redoStack.append(revision)
            restore(previous)
            return
        }
    }

    func redoText() async {
        let documentID = document.id
        await stopInput()
        guard document.id == documentID else { return }
        guard let next = redoStack.popLast() else { return }
        undoStack.append(revision)
        restore(next)
    }

    func readBack() async {
        await stopInput()
        let utterance = AVSpeechUtterance(string: document.text)
        utterance.rate = 0.46
        speaker.speak(utterance)
    }

    func replay() async {
        await stopInput()
        guard !document.text.isEmpty else { return }
        visibleCharacters = 0
        isReplaying = true
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            visibleCharacters = nil; isReplaying = false; return
        }
        let total = Double(document.text.utf16.count)
        replayTask = Task { [weak self] in
            var last = ProcessInfo.processInfo.systemUptime
            var position = 0.0
            while position < total {
                do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
                let now = ProcessInfo.processInfo.systemUptime
                position = min(total, position + min(0.05, now - last) * 42 * (self?.document.revealPace ?? 1))
                last = now
                self?.visibleCharacters = position
            }
            self?.visibleCharacters = nil
            self?.isReplaying = false
        }
    }

    func stopReplay() {
        replayTask?.cancel()
        replayTask = nil
        visibleCharacters = nil
        isReplaying = false
    }

    func importPhotos() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        picker.allowsMultipleSelection = true
        picker.message = "Keep a few memories beside your letter. Photos stay on this Mac."
        guard picker.runModal() == .OK else { return }
        for url in picker.urls.prefix(max(0, 12 - document.photos.count)) {
            do {
                let data = try Data(contentsOf: url)
                guard data.count <= 30_000_000, let image = NSImage(data: data), image.size.width > 0 else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                // Downsample imported references so the autosaved document remains small.
                let ratio = min(1, 1400 / max(image.size.width, image.size.height))
                let resized = NSImage(size: NSSize(width: image.size.width * ratio, height: image.size.height * ratio))
                resized.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: resized.size))
                resized.unlockFocus()
                guard let tiff = resized.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                document.photos.append(ReferencePhoto(data: jpeg, caption: url.deletingPathExtension().lastPathComponent))
            } catch { self.error = "Couldn't import \(url.lastPathComponent). Choose a photo under 30 MB." }
        }
    }

    func exportPDF() {
        let picker = NSSavePanel()
        picker.allowedContentTypes = [.pdf]
        picker.nameFieldStringValue = safeFilename + ".pdf"
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do { try layout.pdfData(includePaperColor: includePaperColor).write(to: url, options: .atomic) }
        catch { self.error = "Couldn't export the PDF: \(error.localizedDescription)" }
    }

    func printLetter() {
        guard let pdf = PDFDocument(data: layout.pdfData(includePaperColor: includePaperColor)) else {
            error = "The print document could not be created."; return
        }
        let info = NSPrintInfo()
        info.paperSize = layout.size
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        guard let operation = pdf.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false) else {
            error = "The Mac print service could not prepare this letter."; return
        }
        operation.jobTitle = document.title
        operation.showsPrintPanel = true
        operation.run()
    }

    func exportDocument() {
        let picker = NSSavePanel()
        picker.nameFieldStringValue = safeFilename + ".letter"
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do { try DocumentStorage.save(document, to: url) }
        catch { self.error = "Couldn't export the letter: \(error.localizedDescription)" }
    }

    func importDocument() async {
        await stopInput()
        let picker = NSOpenPanel()
        picker.allowsMultipleSelection = false
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            var imported = try DocumentStorage.load(from: url)
            imported.id = UUID()
            guard saveNow() else { return }
            document = imported
            clearHistory()
            saveNow()
        } catch { self.error = "This file isn't a supported Letter Studio document." }
    }

    private var safeFilename: String {
        let value = document.title.components(separatedBy: CharacterSet(charactersIn: "/:\n")).joined(separator: " ")
        return value.isEmpty ? "Letter" : String(value.prefix(100))
    }
}
