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
    var includePaperColor = false
    var error: String?
    var saveStatus = "Saved on this Mac"
    var focusMode = false
    var isReplaying = false
    var visibleCharacters: Double?
    var commandMode = false
    var commandTranscript = ""
    let speech = SpeechController()
    private var savedTextForUndo: String?
    private var saveTask: Task<Void, Never>?
    private var replayTask: Task<Void, Never>?
    private var inkTask: Task<Void, Never>?
    private let storage: URL?
    private let speaker = AVSpeechSynthesizer()
    enum Panel: String, CaseIterable { case context = "Context", writing = "Writing", materials = "Materials" }

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

    var canUndo: Bool { savedTextForUndo != nil }
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

    func newLetter() async {
        await stopInput()
        guard saveNow() else { return }
        document = LetterDocument()
        savedTextForUndo = nil
        panel = .context
        showLibrary = false
        saveNow()
    }

    func select(_ letter: LetterDocument) async {
        await stopInput()
        guard saveNow() else { return }
        document = library.first(where: { $0.id == letter.id }) ?? letter
        savedTextForUndo = nil
        showLibrary = false
    }

    func toggleDictation() async {
        if commandMode { await finishCommand(); return }
        if isBusy { await speech.stop(); return }
        stopReplay()
        speaker.stopSpeaking(at: .immediate)
        savedTextForUndo = document.text
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

    func toggleCommand() async {
        if commandMode { await finishCommand(); return }
        await stopInput()
        commandMode = true
        commandTranscript = ""
        await speech.start { [weak self] text in self?.commandTranscript = text }
        if speech.state == .idle { commandMode = false }
    }

    private func finishCommand() async {
        await speech.stop()
        guard commandMode else { return }
        let text = commandTranscript
        commandMode = false
        commandTranscript = ""
        guard let command = VoiceCommand.parse(text) else {
            error = "Try “new paragraph”, “undo”, “read it back”, “print preview”, or “replace [words] with [new words]”. Your letter hasn't changed."
            return
        }
        switch command {
        case .paragraph:
            savedTextForUndo = document.text
            document.text = document.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
        case .undo: await undoText()
        case .readBack: await readBack()
        case .printPreview: showPrint = true
        case let .replace(old, new):
            guard let updated = VoiceCommand.replacing(old, with: new, in: document.text) else {
                error = "I couldn't identify exactly one occurrence of “\(old)”. Choose Writing to make this edit precisely."
                return
            }
            savedTextForUndo = document.text
            document.text = updated
        }
    }

    func receiveDictation(_ text: String) {
        guard text != document.text else { return }
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
                self.visibleCharacters = min(target, position + elapsed * speed)
                if self.visibleCharacters == target { break }
            }
            self?.visibleCharacters = nil
            self?.inkTask = nil
        }
    }

    func edit() async {
        await stopInput()
        savedTextForUndo = document.text
        panel = .writing
    }

    func undoText() async {
        await stopInput()
        guard let previous = savedTextForUndo else { return }
        savedTextForUndo = document.text
        document.text = previous
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
                position = min(total, position + min(0.05, now - last) * 42)
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
            savedTextForUndo = nil
            saveNow()
        } catch { self.error = "This file isn't a supported Letter Studio document." }
    }

    private var safeFilename: String {
        let value = document.title.components(separatedBy: CharacterSet(charactersIn: "/:\n")).joined(separator: " ")
        return value.isEmpty ? "Letter" : String(value.prefix(100))
    }
}
