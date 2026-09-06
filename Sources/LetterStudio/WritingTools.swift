import SwiftUI
import LetterCore

struct FontGallery: View {
    @Bindable var model: StudioModel
    @State private var sample = "Dear you, some things deserve a letter."
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SmallLabel(text: "A voice on paper").foregroundStyle(Palette.muted)
                    Text("Find your lettering.").font(.system(size: 30, design: .serif))
                }
                Spacer()
                Button("Done") { model.showFonts = false }.buttonStyle(.borderedProminent).tint(Palette.text)
            }
            TextField("Preview your own words", text: $sample)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Font preview text")
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Handwriting.allCases, id: \.self) { style in
                        Button { model.chooseFont(style) } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text(style.name).font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Image(systemName: model.document.handwriting == style ? "checkmark.circle.fill" : "circle")
                                }
                                Text(sample.isEmpty ? "Dear you," : sample)
                                    .font(.custom(style.fontName, size: 25)).lineLimit(3)
                                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                                Text(style.subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted)
                            }.padding(18).background(model.document.handwriting == style ? Color.white.opacity(0.85) : Color.white.opacity(0.3))
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(model.document.handwriting == style ? Palette.accent : Palette.text.opacity(0.12), lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityLabel("Choose \(style.name)")
                    }
                }.padding(2)
            }
            Text("Your choice updates the letter and its printed pages together.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
        }.foregroundStyle(Palette.text).padding(28).frame(width: 750, height: 640).background(Palette.cream)
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
        VStack(alignment: .leading, spacing: 18) {
            SmallLabel(text: "Revise as you speak").foregroundStyle(Palette.muted)
            Text("A little more like you.").font(.system(size: 23, design: .serif))
            Text("Say an edit, then apply it. The words you say here are instructions for your letter.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text("Try “replace afternoon with evening”.")
                .font(.system(size: 11, design: .serif)).italic().foregroundStyle(Palette.muted)
            Button { Task { await model.toggleCommand() } } label: {
                Label(model.commandMode ? "Apply edit" : "Speak an edit", systemImage: model.commandMode ? "checkmark" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Palette.text)
                .disabled(model.speech.state == .finishing || model.speech.state == .preparing)
            if model.commandMode {
                Text(model.commandTranscript.isEmpty ? "Listening…" : model.commandTranscript)
                    .font(.system(size: 13)).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.6)).accessibilityLabel("Recognized edit")
                Button("Cancel edit") { Task { await model.stopInput(); model.commandFeedback = "Edit cancelled." } }
                    .buttonStyle(.plain).font(.system(size: 11))
            } else {
                TextField("Or type an edit…", text: $model.commandInput, axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder).font(.system(size: 12))
                    .accessibilityLabel("Edit instruction")
                Button("Apply typed edit", systemImage: "arrow.turn.down.left") {
                    Task { await model.applyVoiceEdit(model.commandInput) }
                }.buttonStyle(.bordered).disabled(model.commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(model.commandFeedback).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Edit result")
            HStack(spacing: 20) {
                Button("Undo", systemImage: "arrow.uturn.backward") { Task { await model.undoText() } }.disabled(!model.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { Task { await model.redoText() } }.disabled(!model.canRedo)
            }.buttonStyle(.plain).font(.system(size: 12))
            if model.lastEditBefore != model.lastEditAfter {
                VStack(alignment: .leading, spacing: 8) {
                    SmallLabel(text: "Last text change").foregroundStyle(Palette.muted)
                    Text(excerpt(model.lastEditBefore, comparedTo: model.lastEditAfter)).strikethrough().foregroundStyle(Palette.muted).lineLimit(3)
                    Text(model.lastEditAfter.isEmpty ? "Text removed" : excerpt(model.lastEditAfter, comparedTo: model.lastEditBefore)).lineLimit(3)
                }.font(.system(size: 11)).padding(12).background(.white.opacity(0.35))
            }
            Divider()
            SmallLabel(text: "Try saying").foregroundStyle(Palette.muted)
            ForEach(examples, id: \.1) { title, example in
                Button { model.commandInput = example } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 11, weight: .semibold))
                        Text("“\(example)”").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).disabled(model.commandMode)
            }
            Text("Use a longer phrase if the same words occur twice. You can also say “undo the last change”, “redo”, “read it back”, or “print preview”.")
                .font(.system(size: 10)).foregroundStyle(Palette.muted)
        }.foregroundStyle(Palette.text)
    }
}
