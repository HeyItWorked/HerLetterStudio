import SwiftUI
import LetterCore

struct SavedDraft: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var name: String
    var document: LetterDocument
}

struct DraftsView: View {
    @Bindable var model: StudioModel
    @State private var name = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Earlier words.").font(.custom("Baskerville", size: 34))
                Spacer()
                Button("Done") { model.showDrafts = false }.keyboardShortcut(.cancelAction)
            }
            Text("Keep a draft before experimenting. Restoring one also keeps a copy of your current letter.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            HStack {
                TextField("Draft name (optional)", text: $name)
                Button("Keep draft") { model.keepDraft(name: name); name = "" }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.drafts.isEmpty {
                        Text("No saved drafts yet. Keep your first version above.").foregroundStyle(Palette.muted)
                    }
                    ForEach(model.drafts) { draft in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(draft.name).font(.custom("Baskerville", size: 22))
                                Text(draft.date, format: .dateTime.month().day().hour().minute()).font(.system(size: 11))
                                Text(String(draft.document.text.replacingOccurrences(of: "\n", with: " ").prefix(140))).font(.system(size: 12)).lineLimit(2)
                            }
                            Spacer()
                            Button("Restore") { Task { await model.restoreDraft(draft) } }
                        }
                        Divider()
                    }
                }.padding(.vertical, 8)
            }
        }.padding(32).frame(width: 620, height: 540).background(Palette.cream).foregroundStyle(Palette.text)
    }
}
