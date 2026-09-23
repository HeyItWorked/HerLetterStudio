import SwiftUI
import LetterCore

struct WalkthroughView: View {
    @Bindable var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                SmallLabel(text: "A letter, from beginning to end")
                Spacer()
                Button("Close") { model.showWalkthrough = false }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
            }.foregroundStyle(Palette.muted)
            Text("Twenty-eight\nordinary years.").font(.custom("Baskerville", size: 44))
            Text("Daniel wants to tell Clara what their life together has meant. Two photographs. A few memories. One page that says what matters.")
                .font(.custom("Baskerville", size: 21)).lineSpacing(4)
            HStack(alignment: .top, spacing: 24) {
                instruction("01", "Meet the brief", "Open a complete sample with photographs and a finished letter.")
                instruction("02", "Watch the ink", "Replay the words onto paper without using your microphone.")
                instruction("03", "Make it yours", "Try a voice edit as text, then review the actual printable page.")
            }
            Button { Task { await model.openWalkthrough() } } label: {
                Label("Open the sample letter", systemImage: "arrow.right").frame(maxWidth: .infinity)
            }.buttonStyle(FolioButton(primary: true))
            Text("A fictional brief with licensed reference photographs. Opens a new saved letter; your current letter is saved first.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
        }.foregroundStyle(Palette.text).padding(38).frame(width: 720).background(Palette.cream)
    }
    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SmallLabel(text: number).foregroundStyle(Palette.accent)
            Text(title).font(.custom("Baskerville", size: 20))
            Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct WalkthroughContext: View {
    @Bindable var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SmallLabel(text: "Sample / Anniversary").foregroundStyle(Palette.muted)
            Text("For Clara.").font(.custom("Baskerville", size: 30))
            Text("From Daniel, after 28 years. Warm and specific: the lake, the cold coffee, the ordinary mornings.")
                .font(.system(size: 12)).lineSpacing(3).foregroundStyle(Palette.muted)
            HStack(spacing: 12) {
                Button { Task { await model.replay() } } label: { Label("Watch", systemImage: "play") }
                Button {
                    model.commandInput = "Replace ordinary with beautiful"
                    model.panel = .voice
                } label: { Text("Try an edit") }
                Button("Print") { model.showPrint = true }
            }.buttonStyle(.plain).font(.system(size: 11)).padding(.vertical, 6)
            Divider()
            ForEach(model.document.photos) { photo in
                VStack(alignment: .leading, spacing: 7) {
                    if let image = NSImage(data: photo.data) {
                        Image(nsImage: image).resizable().scaledToFill().frame(height: 135).clipped()
                    }
                    Text(photo.caption).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            Text("The photographs are memories to write from. Only the letter is printed.")
                .font(.system(size: 10)).foregroundStyle(Palette.muted)
        }.foregroundStyle(Palette.text)
    }
}
