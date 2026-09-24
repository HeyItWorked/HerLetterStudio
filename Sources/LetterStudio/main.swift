import AppKit
import SwiftUI
import LetterCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var model: StudioModel!
    private var terminationPending = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        print("launching with args: \(arguments)")
        if arguments.contains("--verify") {
            Task {
                do { try await AppVerification.run(); exit(0) }
                catch { print("FAIL: \(error)"); exit(1) }
            }
            return
        }
        let snapshotIndex = arguments.firstIndex(of: "--snapshot")
        model = StudioModel(inMemory: snapshotIndex != nil)
        let compact = arguments.contains("--compact")
        let size = NSSize(width: compact ? 1060 : 1380, height: compact ? 760 : 930)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "LetterStudio"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.backgroundColor = NSColor(rgb: 0x261C18)
        window.minSize = NSSize(width: 1020, height: 760)
        window.contentView = NSHostingView(rootView: WorkspaceView(model: model).padding(.top, 25).background(Palette.deep))
        window.center()
        if snapshotIndex == nil { window.setFrameAutosaveName("LetterStudioMain") }
        makeMenu()
        NSApp.applicationIconImage = appIcon()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // HACK: without this the title field grabs focus on launch
        Task { try? await Task.sleep(for: .milliseconds(150)); window.makeFirstResponder(nil) }
        print("LetterStudio window: \(window.windowNumber)")
        if arguments.contains("--demo"), snapshotIndex == nil { Task { await model.openWalkthrough() } }
        if let snapshotIndex, arguments.indices.contains(snapshotIndex + 1) {
            if arguments.contains("--demo"), let sample = try? Walkthrough.letter() { model.document = sample; model.walkthroughID = sample.id }
            if arguments.contains("--drafts") { model.keepDraft(name: "First thoughts"); model.showDrafts = true }
            if arguments.contains("--editor") { model.showEditor = true }
            if arguments.contains("--paper") { model.showPaper = true }
            if arguments.contains("--walkthrough") { model.showWalkthrough = true }
            if arguments.contains("--focus") { model.focusMode = true }
            if arguments.contains("--preparing") { model.speech.state = .preparing; model.speech.status = "Preparing on-device dictation…" }
            if arguments.contains("--fonts") { model.showFonts = true }
            if arguments.contains("--voice-edit") { model.panel = .voice }
            if arguments.contains("--expression") { model.panel = .materials; model.chooseExpression(.tender); model.chooseInk(.oxblood) }
            if arguments.contains("--materials") { model.panel = .materials; model.document.stationery = .blue }
            if arguments.contains("--writing") { model.panel = .writing }
            if arguments.contains("--library") { model.showLibrary = true }
            if arguments.contains("--blank") { model.document = LetterDocument() }
            if arguments.contains("--print-preview") { model.showPrint = true }
            let destination = arguments[snapshotIndex + 1]
            Task {
                try? await Task.sleep(for: .seconds(2)) // wait for swiftui to draw, 2s seems enough
                capture(to: destination)
                // Verification runs have no persistent document. A presented sheet
                // otherwise defers normal application termination indefinitely.
                exit(0)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if terminationPending { return .terminateLater }
        terminationPending = true
        Task {
            let saved = await model.prepareToClose()
            if !saved { window.makeKeyAndOrderFront(nil) }
            terminationPending = false
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }
    func applicationWillTerminate(_ notification: Notification) { model?.saveNow() }
    private func makeMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem()
        bar.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About LetterStudio", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide LetterStudio", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit LetterStudio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let file = NSMenu(title: "File")
        file.addItem(withTitle: "New Letter", action: #selector(newLetter), keyEquivalent: "n")
        file.addItem(withTitle: "Open Letter…", action: #selector(openLetter), keyEquivalent: "o")
        file.addItem(withTitle: "Save", action: #selector(save), keyEquivalent: "s")
        file.addItem(withTitle: "Export Letter…", action: #selector(exportLetter), keyEquivalent: "")
        file.addItem(.separator())
        file.addItem(withTitle: "Print Preview…", action: #selector(printPreview), keyEquivalent: "p")
        let fileItem = NSMenuItem(); fileItem.submenu = file; bar.addItem(fileItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: #selector(undo(_:)), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: #selector(redo(_:)), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Edit Letter", action: #selector(editLetter), keyEquivalent: "e")
        let dictate = edit.addItem(withTitle: "Begin / Finish Dictation", action: #selector(dictate), keyEquivalent: "d")
        dictate.keyEquivalentModifierMask = [.command, .shift]
        let editItem = NSMenuItem(); editItem.submenu = edit; bar.addItem(editItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let windowItem = NSMenuItem(); windowItem.submenu = windowMenu; bar.addItem(windowItem)
        NSApp.mainMenu = bar
        NSApp.windowsMenu = windowMenu
        // Action methods belong to the delegate; text editing stays on the responder chain.
        for menu in [file, edit, appMenu] {
            for item in menu.items where ["newLetter", "openLetter", "save", "exportLetter", "printPreview", "editLetter", "dictate", "about"].contains(item.action?.description ?? "") {
                item.target = self
            }
        }
    }
    @objc func undo(_ sender: Any?) { Task { await model.undoText() } }
    @objc func redo(_ sender: Any?) { Task { await model.redoText() } }
    @objc func newLetter() { Task { await model.newLetter() } }
    @objc func openLetter() { Task { await model.importDocument() } }
    @objc func save() { model.saveNow() }
    @objc func exportLetter() { model.exportDocument() }
    @objc func printPreview() { Task { await model.stopInput(); model.showPrint = true } }
    @objc func editLetter() { Task { await model.edit() } }
    @objc func dictate() { Task { await model.toggleDictation() } }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "LetterStudio", .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "Personal correspondence, thoughtfully made.\nInspired by the letter-writing workspace in Her.\n\nHandwriting: La Belle Aurore, Caveat, Nothing You Could Do.\nFont licenses are bundled with the application.")
        ])
    }
    private func capture(to path: String) {
        guard let view = window.attachedSheet?.contentView ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        do {
            try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            try model.layout.pdfData().write(to: URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension("pdf"))
            print("Snapshot and sample PDF saved: \(path)")
        } catch { print("Snapshot failed: \(error)") }
    }
    private func appIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 256, height: 256))
        image.lockFocus()
        NSColor(rgb: 0x244D50).setFill()
        NSBezierPath(roundedRect: NSRect(x: 8, y: 8, width: 240, height: 240), xRadius: 52, yRadius: 52).fill()
        NSColor(rgb: 0xF6F0DF).setFill()
        let page = NSBezierPath(roundedRect: NSRect(x: 64, y: 44, width: 136, height: 174), xRadius: 3, yRadius: 3)
        page.fill()
        ("L" as NSString).draw(at: NSPoint(x: 91, y: 71), withAttributes: [
            .font: NSFont(name: "LaBelleAurore", size: 120) ?? .systemFont(ofSize: 100),
            .foregroundColor: NSColor(rgb: 0x344D75)
        ])
        image.unlockFocus()
        return image
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
