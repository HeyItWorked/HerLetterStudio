import SwiftUI
import LetterCore

enum Palette {
    static let desk = Color(hex: 0x254643)
    static let deep = Color(hex: 0x102B2C)
    static let mist = Color(hex: 0xD0DBD0)
    static let cream = Color(hex: 0xF4EFDF)
    static let panel = Color(hex: 0xEEEADD)
    static let text = Color(hex: 0x293F39)
    static let muted = Color(hex: 0x626B5D)
    static let brass = Color(hex: 0xE1CDA6)
    static let accent = Color(hex: 0xA5533D)
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(rgb: hex)) }
}

struct ThreadMark: View {
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            Ellipse().stroke(lineWidth: 2.6).frame(width: size * 0.7, height: size * 0.42).rotationEffect(.degrees(-40)).offset(x: -size * 0.18)
            Ellipse().stroke(lineWidth: 2.6).frame(width: size * 0.7, height: size * 0.42).rotationEffect(.degrees(-40)).offset(x: size * 0.18)
        }.frame(width: size * 1.25, height: size).accessibilityHidden(true)
    }
}

struct SmallLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2.1)
    }
}

struct StudioButton: ButtonStyle {
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        InstrumentSurface(filled: filled, pressed: configuration.isPressed) { configuration.label }
    }
}

private struct InstrumentSurface<Content: View>: View {
    var filled: Bool
    var pressed: Bool
    @ViewBuilder var content: () -> Content
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        content().font(.custom("AvenirNext-Medium", size: 12))
            .padding(.horizontal, 17).padding(.vertical, 12)
            .foregroundStyle(filled ? Palette.deep : Palette.cream)
            .background(filled ? Palette.cream.opacity(hovered ? 1 : 0.94) : Color.white.opacity(hovered ? 0.09 : 0.025))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(filled ? Color.white.opacity(0.4) : Palette.cream.opacity(hovered ? 0.35 : 0.16), lineWidth: 0.6))
            .shadow(color: .black.opacity(filled ? 0.12 : 0), radius: 4, y: 2)
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
    }
}

struct FolioButton: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.custom("AvenirNext-Medium", size: 12))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(primary ? Palette.cream : Palette.text)
            .background(primary ? Palette.text : Palette.text.opacity(configuration.isPressed ? 0.08 : 0.015))
            .overlay(Rectangle().stroke(Palette.text.opacity(primary ? 1 : 0.25), lineWidth: 0.6))
            .opacity(enabled ? configuration.isPressed ? 0.8 : 1 : 0.4)
    }
}

struct RailButton: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 18, weight: .light))
                Text(title).font(.custom("AvenirNext-Medium", size: 9))
            }
            .foregroundStyle(selected || hovered ? Palette.cream : Palette.mist)
            .frame(width: 66, height: 62)
            .contentShape(Rectangle())
            .background(Color.white.opacity(selected ? 0.065 : hovered ? 0.035 : 0))
            .overlay(alignment: .leading) {
                if selected { Rectangle().fill(Palette.brass).frame(width: 2, height: 25) }
            }
        }.buttonStyle(.plain).onHover { hovered = $0 }.help(title).accessibilityLabel(title)
    }
}

struct DeskBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x3D5E55), Palette.desk, Palette.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(hex: 0xA9B49A).opacity(0.15), .clear], center: UnitPoint(x: 0.25, y: 0.28), startRadius: 30, endRadius: proxy.size.width * 0.65)
                Canvas { context, size in
                    for index in 0..<2500 {
                        let x = CGFloat((index * 137 + 43) % 1999) / 1999 * size.width
                        let y = CGFloat((index * 293 + 11) % 1987) / 1987 * size.height
                        context.fill(Path(CGRect(x: x, y: y, width: 0.6, height: 0.6)), with: .color(.white.opacity(0.035)))
                    }
                }
                LinearGradient(colors: [.black.opacity(0.12), .clear, .black.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct MemorySketch: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Color(hex: 0xD7D9C7)
                Circle().fill(Color(hex: 0xEADDB6)).frame(width: 32).offset(x: w * 0.2, y: -h * 0.2)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.56))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.6), control1: CGPoint(x: w * 0.3, y: h * 0.3), control2: CGPoint(x: w * 0.6, y: h * 0.8))
                    p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                }.fill(Color(hex: 0x8EA7A0))
                Rectangle().fill(Color(hex: 0x6F908B)).frame(height: h * 0.25).frame(maxHeight: .infinity, alignment: .bottom)
                ForEach(0..<6) { i in
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: CGFloat(23 + i * 8), height: 1)
                        .offset(x: CGFloat(i * 17 - 45), y: h * 0.32 + CGFloat(i * 3))
                }
            }
        }.accessibilityLabel("Illustration of a quiet shoreline")
    }
}
