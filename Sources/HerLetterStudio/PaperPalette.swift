import SwiftUI
import LetterCore

struct PaperPalette: View {
    @Bindable var model: StudioModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                SmallLabel(text: "The stationery drawer").foregroundStyle(Palette.muted)
                Text("The weight\nof a word.").font(.custom("Baskerville", size: 33))
                ForEach(PaperMaterial.allCases, id: \.self) { material in
                    Button { model.chooseMaterial(material) } label: {
                        HStack {
                            Text(material.name).font(.custom("Baskerville", size: 20))
                            Spacer()
                            if (model.document.material ?? .bond) == material { Image(systemName: "checkmark").font(.system(size: 11)) }
                        }.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.text.opacity(0.15)).frame(height: 0.5) }
                    }.buttonStyle(.plain).accessibilityLabel("Choose \(material.name)")
                }
                Spacer(minLength: 0)
            }.padding(28).frame(width: 248).background(Color(hex: 0xE5DFD0))
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SmallLabel(text: "Surface / Preview")
                    Spacer()
                    Button("Done") { model.showPaper = false }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                }.font(.system(size: 12)).foregroundStyle(Palette.muted)
                PaperView(layout: model.layout, width: 275)
                    .shadow(color: .black.opacity(0.16), radius: 12, x: 4, y: 9)
                    .frame(maxWidth: .infinity)
                Text((model.document.material ?? .bond).detail).font(.custom("Baskerville-Italic", size: 18))
                Text("Digital surface preview. Print ink only on matching stationery, or include color and texture when exporting.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(28).frame(maxWidth: .infinity)
        }.foregroundStyle(Palette.text).frame(width: 660, height: 570).background(Palette.cream)
    }
}
