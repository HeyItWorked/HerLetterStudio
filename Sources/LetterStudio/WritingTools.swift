import SwiftUI
import LetterCore

struct FontGallery: View {
    @Bindable var model: StudioModel
    @State private var sample = "Dear you,\n\nSome things deserve a letter.\nA memory. A little gratitude.\n\nWith love,"
    @State private var editingSample = false
    @FocusState private var doneFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SmallLabel(text: "The type collection").foregroundStyle(Palette.muted)
                Text("A voice\non paper.").font(.custom("Baskerville", size: 35)).lineSpacing(-2).padding(.top, 16).padding(.bottom, 28)
                ScrollView {
                VStack(spacing: 0) {
                ForEach(Array(Handwriting.galleryOrder.enumerated()), id: \.element) { index, style in
                    Button { model.chooseFont(style) } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", index + 1)).font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Palette.muted)
                            Text(style.name).font(.custom("AvenirNext-Medium", size: 13))
                            Spacer()
                            if model.document.handwriting == style { Image(systemName: "arrow.right").font(.system(size: 11)) }
                        }.padding(.vertical, 15).padding(.horizontal, 10)
                            .contentShape(Rectangle())
                            .background(model.document.handwriting == style ? Palette.text.opacity(0.065) : .clear)
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.text.opacity(0.12)).frame(height: 0.5) }
                    }.buttonStyle(.plain).accessibilityLabel("Choose \(style.name)")
                        .accessibilityAddTraits(model.document.handwriting == style ? .isSelected : [])
                }
                }
                }.scrollIndicators(.visible)
                Spacer(minLength: 18)
                Text("\(Handwriting.allCases.count) ways to make\nyourself heard.").font(.custom("Baskerville-Italic", size: 16)).foregroundStyle(Palette.muted)
            }.padding(30).frame(width: 258).frame(maxHeight: .infinity).background(Color(hex: 0xE5E1D3))
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SmallLabel(text: "Specimen / \(model.document.handwriting.name)").foregroundStyle(Palette.muted)
                    Spacer()
                    Button("Done") { model.showFonts = false }.buttonStyle(.plain).focused($doneFocused).keyboardShortcut(.cancelAction).font(.custom("AvenirNext-Medium", size: 12))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(Rectangle().stroke(Palette.text.opacity(0.25), lineWidth: 0.6))
                }.padding(.bottom, 24)
                HStack(alignment: .firstTextBaseline) {
                    Text("Aa").font(.custom(model.document.handwriting.fontName, size: 70))
                    Spacer()
                    Text(model.document.handwriting.subtitle).font(.custom("Baskerville-Italic", size: 16)).foregroundStyle(Palette.muted)
                }.frame(height: 95)
                Rectangle().fill(Palette.text.opacity(0.18)).frame(height: 0.5).padding(.bottom, 22)
                Group {
                    if editingSample {
                        TextEditor(text: $sample)
                            .scrollContentBackground(.hidden).background(.clear)
                            .accessibilityLabel("Editable font specimen")
                    } else {
                        Button { editingSample = true } label: {
                            Text(sample.isEmpty ? "Your words go here." : sample)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Edit font specimen").accessibilityValue(sample)
                    }
                }.font(.custom(model.document.handwriting.fontName, size: 24)).lineSpacing(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Button { editingSample.toggle() } label: {
                    Label(editingSample ? "Finish editing sample" : "Edit sample text", systemImage: editingSample ? "checkmark" : "pencil.tip")
                        .font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(Palette.muted).padding(.top, 18)

            }.padding(32).background(Palette.cream)
                .overlay(alignment: .leading) { LinearGradient(colors: [.black.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing).frame(width: 12).allowsHitTesting(false) }
        }.foregroundStyle(Palette.text).frame(width: 820, height: 650)
            .defaultFocus($doneFocused, true)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.document.handwriting)
    }
}

struct VoiceEditPanel: View {
    @Bindable var model: StudioModel
    private let examples = [
        ("Replace a phrase", "Replace afternoon with evening"),
        ("Remove words", "Delete by the water"),
        ("Add words", "Insert beautiful before afternoon"),
        ("Trim the ending", "Delete the last sentence"),
        ("Start a paragraph", "New paragraph"),
        ("Change lettering", "Use Baskerville"),
        ("Adjust size", "Set font size to 22")
    ]
    private func excerpt(_ text: String, comparedTo other: String) -> String {
        let characters = Array(text)
        let shared = zip(characters, other).prefix { $0 == $1 }.count
        let start = max(0, shared - 24)
        let end = min(characters.count, shared + 100)
        return (start > 0 ? "…" : "") + String(characters[start..<end]) + (end < characters.count ? "…" : "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SmallLabel(text: "Spoken revisions").foregroundStyle(Palette.muted)
            Text("Make it yours.").font(.custom("Baskerville", size: 29))
            Text("Speak an edit, or write an instruction below.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            Button { Task { await model.toggleCommand() } } label: {
                Label(model.commandMode ? "Apply edit" : "Speak an edit", systemImage: model.commandMode ? "checkmark" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(FolioButton(primary: true))
                .disabled(model.speech.state == .finishing || model.speech.state == .preparing)
            if model.commandMode {
                Text(model.commandTranscript.isEmpty ? "Listening…" : model.commandTranscript)
                    .font(.custom("Baskerville", size: 19)).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel("Recognized edit")
                Button("Cancel edit") { Task { await model.stopInput(); model.commandFeedback = "Edit cancelled." } }
                    .buttonStyle(.plain).font(.system(size: 11))
            } else {
                TextField("e.g. replace afternoon with evening", text: $model.commandInput, axis: .vertical)
                    .lineLimit(2...3).textFieldStyle(.plain).font(.system(size: 12)).padding(10)
                    .background(.white.opacity(0.3))
                    .overlay(Rectangle().stroke(Palette.text.opacity(0.22), lineWidth: 0.6))
                    .accessibilityLabel("Edit instruction")
                Button { Task { await model.applyVoiceEdit(model.commandInput) } } label: {
                    Label("Apply instruction", systemImage: "arrow.turn.down.left").frame(maxWidth: .infinity)
                }.buttonStyle(FolioButton()).disabled(model.commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if model.commandFeedback != "Say what you want to change." {
                Text(model.commandFeedback).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Edit result").padding(.vertical, 3)
            }
            HStack(spacing: 20) {
                Button("Undo", systemImage: "arrow.uturn.backward") { Task { await model.undoText() } }.disabled(!model.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { Task { await model.redoText() } }.disabled(!model.canRedo)
            }.buttonStyle(.plain).font(.system(size: 11)).padding(.vertical, 4)
            if model.lastEditBefore != model.lastEditAfter {
                VStack(alignment: .leading, spacing: 8) {
                    SmallLabel(text: "Last text change").foregroundStyle(Palette.muted)
                    Text(excerpt(model.lastEditBefore, comparedTo: model.lastEditAfter)).strikethrough().foregroundStyle(Palette.muted).lineLimit(3)
                    Text(model.lastEditAfter.isEmpty ? "Text removed" : excerpt(model.lastEditAfter, comparedTo: model.lastEditBefore)).lineLimit(3)
                }.font(.system(size: 11)).padding(.vertical, 8)
            }
            Divider().padding(.vertical, 5)
            SmallLabel(text: "Try an edit").foregroundStyle(Palette.muted)
            ForEach(examples.prefix(2), id: \.1) { _, example in exampleButton(example) }
            DisclosureGroup("More instructions") {
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(examples.dropFirst(2), id: \.1) { _, example in exampleButton(example) }
                    Text("Also: “undo the last change”, “redo”, “read it back”, or “print preview”. Use a longer phrase if your words appear twice.")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }.padding(.top, 10)
            }.font(.system(size: 11)).tint(Palette.text).padding(.top, 3)
        }.foregroundStyle(Palette.text)
    }

    private func exampleButton(_ example: String) -> some View {
        Button { model.commandInput = example } label: {
            HStack(alignment: .firstTextBaseline) {
                Text("“\(example)”").font(.custom("Baskerville-Italic", size: 15))
                Spacer(minLength: 5)
                Image(systemName: "arrow.up.left").font(.system(size: 9))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.plain).disabled(model.commandMode)
    }
}
