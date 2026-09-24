import SwiftUI
import LetterCore

struct PaperDesk: View {
    @Bindable var model: StudioModel
    @State private var scale: Double? = nil
    @State private var fitWidth = false
    @State private var page = 0
    @State private var follow = false
    @State private var gestureScale: Double? = nil
    var body: some View {
        GeometryReader { geometry in
            let available = max(100, geometry.size.width - 40)
            let fitted = min(available / model.layout.size.width,
                max(100, geometry.size.height - 112) / model.layout.size.height)
            let zoom: Double = scale ?? Double(fitWidth ? available / model.layout.size.width : fitted)
            let width = model.layout.size.width * CGFloat(zoom)
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Menu {
                            Button("Fit page") { scale = nil; fitWidth = false }
                            Button("Fit width") { scale = nil; fitWidth = true }
                            ForEach([50, 75, 100, 125, 150, 200, 300], id: \.self) { value in
                                Button("\(value)%") { scale = Double(value) / 100 }
                            }
                        } label: {
                            Text("\(Int(zoom * 100))%\(scale == nil ? (fitWidth ? " · Width" : " · Fit") : "")")
                                .monospacedDigit().frame(minWidth: 78)
                        }.help("Preview scale only; printing size is unchanged")
                        Button { scale = max(0.25, zoom / 1.2) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 30, height: 30).contentShape(Rectangle()) }
                            .accessibilityLabel("Zoom out").keyboardShortcut("-", modifiers: .command)
                        Button { scale = min(3, zoom * 1.2) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 30, height: 30).contentShape(Rectangle()) }
                            .accessibilityLabel("Zoom in").keyboardShortcut("=", modifiers: .command)
                        Button { scale = nil; fitWidth = false } label: { Text("Fit").frame(width: 30, height: 30).contentShape(Rectangle()) }.keyboardShortcut("0", modifiers: .command)
                        Spacer(minLength: 0)
                        Menu("Pages · \(model.layout.pages.count)") {
                            ForEach(model.layout.pages.indices, id: \.self) { index in
                                Button("Page \(index + 1)") { page = index; follow = false; proxy.scrollTo(index, anchor: .top) }
                            }
                        }.fixedSize()
                        Toggle(isOn: $follow) { Image(systemName: "text.line.last.and.arrowtriangle.forward") }
                            .toggleStyle(.button).help("Follow new dictation pages")
                            .accessibilityLabel("Follow dictation")
                    }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Palette.cream)
                        .padding(.horizontal, 16).frame(height: 40)
                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 28) {
                            ForEach(model.layout.pages.indices, id: \.self) { index in
                                VStack(spacing: 12) {
                                    HStack {
                                        SmallLabel(text: "Page \(index + 1)")
                                        Spacer()
                                        Button("Edit text", systemImage: "pencil") { Task { await model.editPage(index) } }
                                            .buttonStyle(.plain).font(.system(size: 11))
                                    }.foregroundStyle(Palette.mist)
                                    PaperView(layout: model.layout, page: index, width: width, visibleCharacters: model.visibleCharacters)
                                        .shadow(color: .black.opacity(0.25), radius: 16, x: 4, y: 12)
                                }.frame(width: width).id(index)
                            }
                        }.padding(20).frame(minWidth: geometry.size.width, alignment: .top)
                    }
                    .simultaneousGesture(MagnificationGesture()
                        .onChanged { value in
                            if gestureScale == nil { gestureScale = zoom }
                            scale = min(3, max(0.25, (gestureScale ?? zoom) * value))
                        }.onEnded { _ in gestureScale = nil })
                    .onChange(of: model.layout.pages.count) { _, count in
                        page = min(page, count - 1)
                        if model.isBusy && follow { page = count - 1; proxy.scrollTo(page, anchor: .bottom) }
                    }
                    .onChange(of: model.document.id) { _, _ in page = 0; proxy.scrollTo(0, anchor: .top) }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x392526)))
            }
        }
    }
}
