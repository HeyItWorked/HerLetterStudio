import SwiftUI
import LetterCore

struct PaperView: View {
    let layout: LetterLayout
    var page = 0
    var width: CGFloat = 520
    var visibleCharacters: Int?
    var decoration = true
    var body: some View {
        let height = width * layout.size.height / layout.size.width
        ZStack {
            Color(hex: layout.document.stationery.hex)
            if decoration {
                LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    for i in 0..<600 {
                        let x = CGFloat((i * 137 + 43) % 997) / 997 * size.width
                        let y = CGFloat((i * 293 + 11) % 991) / 991 * size.height
                        let rect = CGRect(x: x, y: y, width: CGFloat(i % 3 + 1), height: 0.4)
                        context.fill(Path(rect), with: .color(.brown.opacity(0.06)))
                    }
                }.allowsHitTesting(false)
            }
            InkView(layout: layout, page: page, visibleCharacters: visibleCharacters)
                .accessibilityLabel("Letter page \(page + 1)")
                .accessibilityValue(layout.document.text)
            if layout.document.text.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Dear…").font(.custom("LaBelleAurore", size: width * 0.05))
                        .foregroundStyle(Color(hex: layout.document.ink.hex).opacity(0.38))
                    Text("A name. A memory. Something you mean.")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted.opacity(0.7))
                    Spacer()
                }.padding(.top, width * 0.13).padding(.leading, width * 0.11)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if decoration {
                PaperFold().fill(LinearGradient(colors: [Color(hex: layout.document.stationery.hex), .white.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 29, height: 34).shadow(color: .black.opacity(0.08), radius: 2, x: -2, y: -2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 1, bottomLeadingRadius: 2, bottomTrailingRadius: decoration ? 26 : 1, topTrailingRadius: 1))
        .overlay(Rectangle().stroke(.white.opacity(0.3), lineWidth: 0.5))
    }
}

struct PaperFold: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: 0))
            p.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY), control: CGPoint(x: rect.maxX * 0.9, y: rect.maxY * 0.9))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.closeSubpath()
        }
    }
}

struct InkView: NSViewRepresentable {
    let layout: LetterLayout
    let page: Int
    let visibleCharacters: Int?
    func makeNSView(context: Context) -> InkNSView { InkNSView() }
    func updateNSView(_ view: InkNSView, context: Context) {
        view.layout = layout; view.page = page; view.visibleCharacters = visibleCharacters
        view.needsDisplay = true
    }
}

final class InkNSView: NSView {
    var layout: LetterLayout?
    var page = 0
    var visibleCharacters: Int?
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let layout, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x: bounds.width / layout.size.width, y: bounds.height / layout.size.height)
        layout.draw(page: page, in: context, visibleUTF16: visibleCharacters)
        context.restoreGState()
    }
}
