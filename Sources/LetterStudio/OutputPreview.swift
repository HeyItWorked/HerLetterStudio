import SwiftUI
import PDFKit

/// Draw the exported PDF pages, including the chosen background option.
struct OutputPreview: View {
    let data: Data
    var body: some View {
        let pdf = PDFDocument(data: data)
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<(pdf?.pageCount ?? 0), id: \.self) { index in
                    if let page = pdf?.page(at: index) {
                        let bounds = page.bounds(for: .mediaBox)
                        PDFPagePreview(page: page)
                            .frame(width: 350, height: 350 * bounds.height / bounds.width)
                    }
                }
            }.padding(20)
        }.background(Color(hex: 0xD6DCD4))
    }
}

private struct PDFPagePreview: NSViewRepresentable {
    let page: PDFPage
    func makeNSView(context: Context) -> PDFPageSurface { PDFPageSurface() }
    func updateNSView(_ view: PDFPageSurface, context: Context) {
        view.page = page
        view.needsDisplay = true
    }
}
private final class PDFPageSurface: NSView {
    var page: PDFPage?
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        guard let page, let context = NSGraphicsContext.current?.cgContext else { return }
        let media = page.bounds(for: .mediaBox)
        context.saveGState()
        context.scaleBy(x: bounds.width / media.width, y: bounds.height / media.height)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
    }
}
