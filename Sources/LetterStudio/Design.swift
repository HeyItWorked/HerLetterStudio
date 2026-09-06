import SwiftUI
import LetterCore

enum Palette {
    static let desk = Color(hex: 0x244D50)
    static let deep = Color(hex: 0x15383B)
    static let mist = Color(hex: 0xA7C4BD)
    static let cream = Color(hex: 0xF4EFDF)
    static let panel = Color(hex: 0xE9E9DE)
    static let text = Color(hex: 0x304B49)
    static let muted = Color(hex: 0x62716A)
    static let accent = Color(hex: 0xBA6550)
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
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(filled ? Palette.deep : Palette.cream)
            .background(filled ? Palette.cream : Color.white.opacity(configuration.isPressed ? 0.15 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.16), lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct RailButton: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 19, weight: .light))
                Text(title).font(.system(size: 9))
            }
            .foregroundStyle(selected ? Palette.cream : Palette.mist)
            .frame(width: 60, height: 58)
            .background(selected ? Color.white.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
}

struct DeskBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x527A76), Palette.desk, Palette.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color(hex: 0x9EBDB3).opacity(0.05 + Double(index) * 0.008), lineWidth: 8)
                        .padding(CGFloat(index) * 12 + 14)
                }
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
