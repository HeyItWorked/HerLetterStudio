import SwiftUI
import AppKit
import LetterCore

struct LetterEditor: View {
    @Bindable var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Find the right words.").font(.custom("Baskerville", size: 30))
                Spacer()
                Button("Done") { model.showEditor = false }.keyboardShortcut(.cancelAction)
            }
            Text("Select words to replace them. Changes appear on your letter and save automatically.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            NativeLetterEditor(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Button("Undo") { Task { await model.undoText() } }.disabled(!model.canUndo)
                Button("Redo") { Task { await model.redoText() } }.disabled(!model.canRedo)
                Spacer()
                Text(model.saveStatus).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }.padding(30).frame(width: 720, height: 620).background(Palette.cream).foregroundStyle(Palette.text)
    }
}

struct NativeLetterEditor: NSViewRepresentable {
    let model: StudioModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let text = NSTextView(frame: .zero)
        text.isRichText = false
        text.allowsUndo = true
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainerInset = NSSize(width: 20, height: 20)
        text.font = NSFont(name: "Baskerville", size: 21)
        text.textColor = NSColor(rgb: 0x3E3028)
        text.backgroundColor = NSColor(rgb: 0xFAF7EF)
        text.string = model.document.text
        text.delegate = context.coordinator
        text.setAccessibilityLabel("Edit letter text")
        scroll.documentView = text
        DispatchQueue.main.async {
            text.window?.makeFirstResponder(text)
            let range = model.editorSelection
            if NSMaxRange(range) <= text.string.utf16.count {
                text.setSelectedRange(range)
                text.scrollRangeToVisible(range)
            }
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? NSTextView, text.string != model.document.text else { return }
        let selection = text.selectedRange()
        text.undoManager?.removeAllActions()
        text.string = model.document.text
        text.setSelectedRange(NSRange(location: min(selection.location, text.string.utf16.count), length: 0))
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: StudioModel
        init(model: StudioModel) { self.model = model }
        func textDidChange(_ notification: Notification) {
            guard let text = notification.object as? NSTextView else { return }
            model.updateTypedText(text.string)
        }
    }
}
