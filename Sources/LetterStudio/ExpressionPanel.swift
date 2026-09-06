import SwiftUI
import LetterCore

struct ExpressionPanel: View {
    @Bindable var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                SmallLabel(text: "The longhand console").foregroundStyle(Palette.muted)
                Text("A feeling, in ink.").font(.custom("Baskerville", size: 29))
                Text("Choose how your words sit on the page.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            VStack(spacing: 0) {
                ForEach(HandExpression.allCases, id: \.self) { expression in
                    let selected = model.document.expression == expression
                    Button { model.chooseExpression(expression) } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Rectangle().fill(selected ? Palette.accent : Palette.text.opacity(0.12)).frame(width: 2, height: 43)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(expression.name).font(.custom(expression.font.fontName, size: 26))
                                Text(expression.description).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) }
                        }.padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("\(expression.name) expression")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    Divider().opacity(0.5)
                }
            }
            VStack(spacing: 8) {
                HStack {
                    SmallLabel(text: "Resonance")
                    Spacer()
                    Text(model.document.expression == nil ? "Off" : "\(Int(model.document.effectiveResonance * 100))")
                        .monospacedDigit().font(.system(size: 11))
                }
                Slider(value: Binding(get: { model.document.effectiveResonance }, set: { model.chooseResonance($0) }), in: 0...1,
                       onEditingChanged: { model.fontSizeDrag($0) })
                    .tint(Palette.accent).accessibilityLabel("Expression resonance")
                HStack {
                    Text("Restrained")
                    Spacer()
                    Text("Expansive")
                }.font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
            HStack {
                Button("Watch the ink", systemImage: "play") { Task { await model.replay() } }
                    .disabled(model.document.text.isEmpty)
                Spacer()
                Button("Reset") { model.resetExpression() }.disabled(model.document.expression == nil)
            }.buttonStyle(.plain).font(.system(size: 11))
            Text("Spacing and reveal pace; your words stay yours.")
                .font(.system(size: 10)).foregroundStyle(Palette.muted)
            Button {
                model.panel = .voice
                model.commandInput = "A little more tender"
            } label: {
                HStack {
                    Image(systemName: "waveform")
                    Text("“A little more tender”")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.font(.system(size: 11)).padding(.vertical, 10).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.foregroundStyle(Palette.text)
    }
}
