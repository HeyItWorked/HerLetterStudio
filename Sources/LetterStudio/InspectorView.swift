import SwiftUI
import LetterCore

struct InspectorView: View {
    @Bindable var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(StudioModel.Panel.allCases, id: \.self) { panel in
                    Button {
                        if panel == .writing { Task { await model.edit() } }
                        else { model.panel = panel }
                    } label: {
                        VStack(spacing: 13) {
                            Text(panel.rawValue).font(.system(size: 11, weight: model.panel == panel ? .semibold : .regular))
                            Rectangle().fill(model.panel == panel ? Palette.accent : .clear).frame(height: 2)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                }
            }.foregroundStyle(Palette.text).padding(.top, 22)
            Divider().overlay(Palette.text.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch model.panel {
                    case .context: contextPanel
                    case .writing: writingPanel
                    case .materials: materialsPanel
                    case .voice: VoiceEditPanel(model: model)
                    }
                }.padding(24)
            }.scrollIndicators(.visible)
            HStack(spacing: 7) {
                Image(systemName: "externaldrive").font(.system(size: 10))
                Text(model.saveStatus).font(.system(size: 10))
            }.foregroundStyle(Palette.muted).padding(20)
        }
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.3), lineWidth: 0.5))
    }

    private var contextPanel: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(text: "The person behind the words").foregroundStyle(Palette.muted)
                TextField("Who is this for?", text: $model.document.recipient)
                    .font(.system(size: 26, design: .serif)).textFieldStyle(.plain)
                    .foregroundStyle(Palette.text).accessibilityLabel("Recipient")
            }
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(text: "The occasion").foregroundStyle(Palette.muted)
                TextField("Just because", text: $model.document.occasion)
                    .font(.system(size: 12)).textFieldStyle(.plain).foregroundStyle(Palette.text)
                    .accessibilityLabel("Occasion")
            }
            Rectangle().fill(Palette.text.opacity(0.17)).frame(height: 0.5)
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(text: "Things to remember").foregroundStyle(Palette.muted)
                TextEditor(text: $model.document.notes)
                    .font(.system(size: 13)).lineSpacing(6).scrollContentBackground(.hidden)
                    .foregroundStyle(Palette.text).frame(minHeight: 95, maxHeight: 130)
                    .accessibilityLabel("Private reference notes")
                Text("Only your letter goes on the page.")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SmallLabel(text: "A few memories").foregroundStyle(Palette.muted)
                    Spacer()
                    Button { model.importPhotos() } label: { Image(systemName: "plus").font(.system(size: 13)) }
                        .buttonStyle(.plain).help("Add reference photographs").disabled(model.document.photos.count >= 12)
                }
                if model.document.photos.isEmpty {
                    Button { model.importPhotos() } label: {
                        VStack(spacing: 0) {
                            MemorySketch().frame(height: 120).padding(7)
                            HStack {
                                Image(systemName: "plus").font(.system(size: 9))
                                Text("Bring a photograph").font(.system(size: 10))
                            }.foregroundStyle(Palette.muted).padding(.bottom, 12).padding(.top, 3)
                        }.background(Color(hex: 0xF7F5EB))
                            .rotationEffect(.degrees(-2))
                            .shadow(color: .black.opacity(0.11), radius: 5, x: 1, y: 4)
                    }.buttonStyle(.plain).padding(.horizontal, 5)
                    Text("A little context helps the words find you.")
                        .font(.system(size: 11, design: .serif)).italic().foregroundStyle(Palette.muted)
                } else {
                    ForEach($model.document.photos) { $photo in
                        VStack(spacing: 8) {
                            if let image = NSImage(data: photo.data) {
                                Image(nsImage: image).resizable().scaledToFill().frame(height: 140).clipped()
                            }
                            HStack {
                                TextField("A memory", text: $photo.caption).textFieldStyle(.plain).font(.system(size: 11))
                                Button {
                                    model.document.photos.removeAll { $0.id == photo.id }
                                } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                                    .buttonStyle(.plain).help("Remove this reference photo")
                            }.foregroundStyle(Palette.muted)
                        }.padding(8).background(Color(hex: 0xF7F5EB))
                    }
                }
            }
        }
    }

    private var writingPanel: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(text: "Make it yours").foregroundStyle(Palette.muted)
                Text("Every word matters.").font(.system(size: 23, design: .serif)).foregroundStyle(Palette.text)
                Text("Write here, or dictate. The page follows along.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            TextEditor(text: Binding(get: { model.document.text }, set: { model.updateTypedText($0) }))
                .font(.system(size: 14)).lineSpacing(7).scrollContentBackground(.hidden)
                .foregroundStyle(Palette.text).padding(10)
                .frame(minHeight: 340).background(.white.opacity(0.38))
                .overlay(Rectangle().stroke(Palette.text.opacity(0.12), lineWidth: 0.5))
                .disabled(model.isBusy).accessibilityLabel("Letter text")
            HStack {
                Button("Read aloud", systemImage: "speaker.wave.2") { Task { await model.readBack() } }
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward") { Task { await model.undoText() } }.disabled(!model.canUndo)
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.text)
            Button("Edit with your voice", systemImage: "waveform") { model.panel = .voice }
                .buttonStyle(.bordered).tint(Palette.text)
            Text("Keyboard edits support ⌘Z. Dictation appends at the end of your letter.")
                .font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
    }

    private var materialsPanel: some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: "Lettering").foregroundStyle(Palette.muted)
                Text(model.document.handwriting.name).font(.custom(model.document.handwriting.fontName, size: 28)).foregroundStyle(Palette.text)
                Text(model.document.handwriting.subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted)
                Button("Browse 7 fonts", systemImage: "textformat") {
                    Task { await model.stopInput(); model.showFonts = true }
                }.buttonStyle(.bordered).tint(Palette.text)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SmallLabel(text: "Size").foregroundStyle(Palette.muted)
                    Spacer()
                    Text("\(Int(model.document.fontSize)) pt").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.text)
                }
                Slider(value: Binding(get: { model.document.fontSize }, set: { model.chooseFontSize($0) }), in: 18...32, step: 1, onEditingChanged: { model.fontSizeDrag($0) }).tint(Palette.text).accessibilityLabel("Handwriting size")
            }
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: "Ink").foregroundStyle(Palette.muted)
                HStack(spacing: 16) {
                    ForEach(Ink.allCases, id: \.self) { ink in
                        Button { model.document.ink = ink } label: {
                            Circle().fill(Color(hex: ink.hex)).frame(width: 24, height: 24)
                                .padding(4).overlay(Circle().stroke(model.document.ink == ink ? Palette.text : .clear, lineWidth: 1))
                        }.buttonStyle(.plain).help(ink.rawValue.capitalized).accessibilityLabel("\(ink.rawValue) ink")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: "Paper").foregroundStyle(Palette.muted)
                HStack(spacing: 12) {
                    ForEach(Stationery.allCases, id: \.self) { paper in
                        Button { model.document.stationery = paper } label: {
                            Rectangle().fill(Color(hex: paper.hex)).frame(width: 34, height: 43)
                                .overlay(Rectangle().stroke(model.document.stationery == paper ? Palette.text : Palette.text.opacity(0.16), lineWidth: model.document.stationery == paper ? 1.5 : 0.5))
                                .shadow(color: .black.opacity(0.08), radius: 2, x: 1, y: 2)
                        }.buttonStyle(.plain).help(paper.name).accessibilityLabel("\(paper.name) stationery")
                    }
                }
                Picker("Page size", selection: $model.document.paper) {
                    ForEach(Paper.allCases, id: \.self) { paper in Text(paper.name).tag(paper) }
                }.font(.system(size: 11)).foregroundStyle(Palette.text)
            }
        }
    }
}
