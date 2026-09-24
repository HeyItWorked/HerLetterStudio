import AppKit
import CoreText

public enum FontLibrary {
    public static func register() {
        guard let directory = Bundle.module.url(forResource: "Fonts", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }
}

public extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: Double((rgb >> 16) & 255) / 255,
                  green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255, alpha: 1)
    }
}

@MainActor public final class LetterLayout {
    public struct Page {
        public let frame: CTFrame
        public let range: NSRange
    }
    public let document: LetterDocument
    public let size: CGSize
    public let pages: [Page]
    public let attributedText: NSAttributedString
    public init(document: LetterDocument) {
        self.document = document
        size = CGSize(width: document.paper.width, height: document.paper.height)
        let paragraph = NSMutableParagraphStyle()
        let fontSize = min(34, max(18, document.fontSize))
        let resonance = document.effectiveResonance
        let lineHeight = document.expression.map { $0.lineHeight + (resonance - 0.5) * 0.18 } ?? 1.5
        paragraph.minimumLineHeight = fontSize * lineHeight
        paragraph.maximumLineHeight = fontSize * lineHeight
        paragraph.lineBreakMode = .byWordWrapping
        let font = NSFont(name: document.handwriting.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        attributedText = NSAttributedString(string: document.text, attributes: [
            .font: font, .foregroundColor: NSColor(rgb: document.ink.hex),
            .paragraphStyle: paragraph, .ligature: 1,
            .kern: document.expression == nil ? 0 : fontSize * resonance * 0.025
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let rect = CGRect(x: 66, y: 58, width: size.width - 132, height: size.height - 122) // dont touch these numbers
        let path = CGPath(rect: rect, transform: nil)
        var result: [Page] = []
        var offset = 0
        repeat {
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            result.append(Page(frame: frame, range: NSRange(location: offset, length: visible.length)))
            guard visible.length > 0 else { break }
            offset += visible.length
        } while offset < attributedText.length
        pages = result
    }
    /// Draws ink in physical page points, with the origin at the bottom left.
    /// Both screen and PDF use this exact function; UI paper effects never enter print output.
    public func draw(page index: Int, in context: CGContext, visibleUTF16: Double? = nil) {
        guard pages.indices.contains(index) else { return }
        context.saveGState()
        context.textMatrix = .identity
        let frame = pages[index].frame
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        let frameOrigin = CTFrameGetPath(frame).boundingBox.origin
        for (i, line) in lines.enumerated() {
            let range = CTLineGetStringRange(line)
            if let visibleUTF16, Double(range.location) >= visibleUTF16 { continue }
            let x = frameOrigin.x + origins[i].x
            let y = frameOrigin.y + origins[i].y
            context.saveGState()
            if let visibleUTF16, visibleUTF16 < Double(range.location + range.length) {
                // Interpolate between composed-character boundaries, preserving ligatures
                // and surrogate pairs while revealing sub-character ink each frame.
                let string = attributedText.string as NSString
                let index = min(string.length - 1, max(0, Int(visibleUTF16)))
                let cluster = string.rangeOfComposedCharacterSequence(at: index)
                let lower = max(range.location, cluster.location)
                let upper = min(range.location + range.length, NSMaxRange(cluster))
                let fraction = min(1, max(0, (visibleUTF16 - Double(lower)) / Double(max(1, upper - lower))))
                let start = CTLineGetOffsetForStringIndex(line, lower, nil)
                let end = CTLineGetOffsetForStringIndex(line, upper, nil)
                let advance = start + (end - start) * fraction
                context.clip(to: CGRect(x: x - 8, y: y - 30, width: max(0, advance + 8), height: 90))
            }
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
            context.restoreGState()
        }
        context.restoreGState()
    }
    /// Shared decorative paper surface. Exported only when paper color is requested.
    public func drawPaper(in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor(rgb: document.stationery.hex).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let material = document.material ?? .bond
        if material == .laid {
            context.setStrokeColor(NSColor.brown.withAlphaComponent(0.08).cgColor)
            context.setLineWidth(0.4)
            for y in stride(from: 0.0, to: size.height, by: 4) {
                context.move(to: CGPoint(x: 0, y: y)); context.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.strokePath()
        }
        if material != .vellum {
            let count = material == .cotton ? 1900 : material == .onion ? 800 : 600
            context.setFillColor(NSColor.brown.withAlphaComponent(material == .onion ? 0.035 : 0.06).cgColor)
            for i in 0..<count {
                let x = Double((i * 137 + 43) % 1999) / 1999 * size.width
                let y = Double((i * 293 + 11) % 1987) / 1987 * size.height
                let width = material == .onion ? Double(i % 7 + 4) : Double(i % 3 + 1)
                context.fillEllipse(in: CGRect(x: x, y: y, width: width, height: material == .onion ? width * 0.35 : 0.45))
            }
        }
        context.restoreGState()
    }
    public func pdfData(includePaperColor: Bool = false) -> Data {
        let data = NSMutableData()
        var bounds = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &bounds, [
                kCGPDFContextTitle: document.title,
                kCGPDFContextCreator: "HerLetterStudio"
              ] as CFDictionary) else { return Data() }
        for index in pages.indices {
            context.beginPDFPage(nil)
            if includePaperColor {
                drawPaper(in: context)
            }
            draw(page: index, in: context)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}
