import AppKit
import LetterCore

/// Fixed-size visual smoke test using events in our own isolated window.
/// Coordinates correspond to the reviewed 1380×930 workspace / 820×650 sheet.
/// This is interaction evidence, not a VoiceOver or full keyboard-accessibility audit.
@MainActor enum InterfaceQA {
    static func click(_ x: CGFloat, _ yFromTop: CGFloat, window: NSWindow) async throws {
        let target = window.attachedSheet ?? window
        guard let content = target.contentView else { throw VerificationFailure.failed("Missing content view") }
        target.makeKeyAndOrderFront(nil)
        let point = content.convert(NSPoint(x: x, y: content.isFlipped ? yFromTop : content.bounds.height - yFromTop), to: nil)
        for kind in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: target.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: kind == .leftMouseDown ? 1 : 0) else {
                throw VerificationFailure.failed("Couldn't create window input")
            }
            NSApp.postEvent(event, atStart: false)
        }
        try await Task.sleep(for: .milliseconds(350))
    }

    static func enter(_ text: String, window: NSWindow) throws {
        let target = window.attachedSheet ?? window
        guard let editor = target.firstResponder as? NSTextView else {
            throw VerificationFailure.failed("Text control didn't accept focus: \(String(describing: target.firstResponder))")
        }
        editor.selectAll(nil)
        editor.insertText(text, replacementRange: editor.selectedRange())
    }

    static func capture(_ name: String, window: NSWindow) throws {
        guard let content = (window.attachedSheet ?? window).contentView,
              let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/" + name + ".png")
        try bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }

    static func run(model: StudioModel, window: NSWindow) async throws {
        try await Task.sleep(for: .milliseconds(500))
        print("Interaction window: \(window.contentView?.bounds ?? .zero)")
        try await click(1115, 104, window: window)
        try AppVerification.check(model.showFonts, "Mouse click didn't open Fonts")
        try await Task.sleep(for: .milliseconds(500))
        print("Sheet bounds: \(window.attachedSheet?.contentView?.bounds ?? .zero), flipped: \(window.attachedSheet?.contentView?.isFlipped ?? false)")
        try await click(130, 183, window: window)
        try enter("romantic", window: window)
        try await Task.sleep(for: .milliseconds(250))
        try await click(130, 263, window: window)
        try AppVerification.check(model.document.handwriting == .parisienne, "hand search did not filter by description")
        try await click(212, 263, window: window)
        try AppVerification.check(model.favoriteHands.contains(.parisienne), "favorite star did not respond")
        try await click(40, 220, window: window)
        try await click(130, 183, window: window)
        try enter("no such hand", window: window)
        try await Task.sleep(for: .milliseconds(250))
        try capture("hand-search-empty", window: window)
        try enter("", window: window)
        try await click(40, 220, window: window)
        try await click(130, 310, window: window)
        try capture("interaction-font-click", window: window)
        try AppVerification.check(model.document.handwriting == .reenie, "Font row selected \(model.document.handwriting.name), expected Reenie Beanie")
        try await click(362, 613, window: window)
        try await click(470, 280, window: window)
        try capture("interaction-before-type", window: window)
        try enter("Dear friend, a sample written through the actual editor.", window: window)
        try await click(378, 613, window: window)
        try capture("interaction-fonts", window: window)
        try await click(755, 48, window: window)
        try AppVerification.check(!model.showFonts, "Done didn't close specimen")
        // Open the archive with the real rail control, then reopen its first row.
        try await click(37, 270, window: window)
        try AppVerification.check(model.showLibrary, "Archive rail didn't open")
        try await click(400, 260, window: window)
        try capture("interaction-before-search", window: window)
        try enter("no-correspondence-matches-this", window: window)
        try await Task.sleep(for: .milliseconds(250))
        try capture("interaction-search", window: window)
        // Escape the query through the focused search field and reopen the row.
        try enter("", window: window)
        try await Task.sleep(for: .milliseconds(250))
        try await click(470, 370, window: window)
        try AppVerification.check(!model.showLibrary, "Archive row didn't reopen letter")
        try await click(1240, 198, window: window)
        try AppVerification.check(model.panel == .materials, "Expression tab did not open")
        try await click(1245, 449, window: window)
        try AppVerification.check(model.document.expression == .familiar && model.document.handwriting == .caveat, "Expression row did not apply its hand")
        try await click(1270, 608, window: window)
        try AppVerification.check(model.document.effectiveResonance > 0.7, "Resonance control did not update")
        try capture("interaction-expression", window: window)
        try await click(1305, 663, window: window)
        try AppVerification.check(model.document.expression == nil, "Expression reset did not respond")
        try await click(1015, 104, window: window)
        try AppVerification.check(model.showPaper, "Paper header button did not open drawer")
        try await click(110, 170, window: window)
        try AppVerification.check(model.document.material == .cotton, "Cotton paper row did not respond")
        try capture("interaction-paper", window: window)
        try await click(615, 58, window: window)
        try AppVerification.check(!model.showPaper, "Paper drawer Done did not respond")
        try await click(37, 752, window: window)
        try AppVerification.check(model.quietMode, "Quiet rail did not respond")
        func ink(in view: NSView?) -> InkNSView? {
            guard let view else { return nil }
            if let ink = view as? InkNSView { return ink }
            for child in view.subviews { if let found = ink(in: child) { return found } }
            return nil
        }
        let initialWidth = ink(in: window.contentView)?.bounds.width ?? 0
        try AppVerification.check(initialWidth > 0, "paper renderer missing")
        try await click(271, 179, window: window)
        let enlarged = ink(in: window.contentView)?.bounds.width ?? 0
        try AppVerification.check(enlarged > initialWidth + 10, "Zoom in did not enlarge paper")
        for _ in 0..<4 { try await click(271, 179, window: window) }
        try capture("interaction-zoom", window: window)
        try await click(311, 179, window: window)
        let fitted = ink(in: window.contentView)?.bounds.width ?? 0
        try AppVerification.check(abs(fitted - initialWidth) < 2, "Fit did not restore paper scale")
        await model.editPage(0)
        try await Task.sleep(for: .milliseconds(400))
        try enter("Dear friend, edited through the spacious writing surface.", window: window)
        try AppVerification.check(model.document.text.contains("spacious writing surface"), "large editor did not update letter")
        try capture("interaction-editor", window: window)
        try await click(660, 48, window: window)
        try AppVerification.check(!model.showEditor, "editor Done did not close")
        print("PASS: native zoom, fit, spacious editor typing and dismissal")
        print("PASS: native hand search/favorite, paper selection and Quiet control")
        print("PASS: native expression selection, resonance control, and reset")
        print("PASS: native mouse/text interaction — font selection, specimen editing, archive search and reopen")
    }
}
