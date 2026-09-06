import SwiftUI
import LetterCore

struct WorkspaceView: View {
    @Bindable var model: StudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 0) {
            rail
            ZStack {
                DeskBackground()
                VStack(spacing: 0) {
                    header.padding(.horizontal, 36).padding(.top, 20).padding(.bottom, 22)
                    HStack(alignment: .top, spacing: 32) {
                        writingDesk
                        if !model.focusMode {
                            InspectorView(model: model).frame(width: 286)
                                .shadow(color: .black.opacity(0.16), radius: 18, x: 5, y: 12)
                                .padding(.top, 12).padding(.bottom, 20)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }.padding(.horizontal, 36)
                    footer.padding(.horizontal, 24).padding(.vertical, 15)
                        .background(Palette.deep.opacity(0.56))
                        .overlay(alignment: .top) { Rectangle().fill(Palette.brass.opacity(0.2)).frame(height: 0.5) }
                }
                if model.showLibrary { LibraryView(model: model).transition(.opacity) }
            }
        }
        .environment(\.quietWriting, model.quietMode)
        .preferredColorScheme(.light)
        .frame(minWidth: 1020, minHeight: 720)
        .sheet(isPresented: $model.showPrint) { PrintPreview(model: model) }
        .sheet(isPresented: $model.showWalkthrough) { WalkthroughView(model: model) }
        .sheet(isPresented: $model.showGuide) { GuideView(model: model) }
        .sheet(isPresented: $model.showPaper) { PaperPalette(model: model) }
        .sheet(isPresented: $model.showFonts) { FontGallery(model: model) }
        .alert("A little attention needed", isPresented: Binding(get: { model.error != nil || model.speech.error != nil }, set: { if !$0 { model.error = nil; model.speech.error = nil } })) {
            Button("OK") { model.error = nil; model.speech.error = nil }
        } message: { Text(model.error ?? model.speech.error ?? "") }
        .animation((reduceMotion || model.quietMode) ? nil : .easeInOut(duration: 0.35), value: model.focusMode)
        .animation((reduceMotion || model.quietMode) ? nil : .easeInOut(duration: 0.25), value: model.showLibrary)
    }

    private var rail: some View {
        VStack(spacing: 12) {
            Text("L.").font(.custom("Baskerville-Italic", size: 37)).foregroundStyle(Palette.brass)
                .accessibilityLabel("Letter Studio").padding(.top, 24).padding(.bottom, 22)
            RailButton(symbol: "square.and.pencil", title: "Write", selected: !model.showLibrary) { model.showLibrary = false }
            RailButton(symbol: "tray.full", title: "Letters", selected: model.showLibrary) { model.showLibrary.toggle() }
            RailButton(symbol: "plus", title: "New") { Task { await model.newLetter() } }
            RailButton(symbol: "play.rectangle", title: "Demo") { model.showWalkthrough = true }
            Spacer()
            RailButton(symbol: model.focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", title: "Focus", selected: model.focusMode) { model.focusMode.toggle() }
            RailButton(symbol: model.quietMode ? "moon.fill" : "moon", title: "Quiet", selected: model.quietMode) { model.quietMode.toggle() }
            RailButton(symbol: "questionmark.circle", title: "Guide") {
                model.showGuide = true
            }
            SmallLabel(text: "PRIVATE").foregroundStyle(Palette.mist).padding(.vertical, 20)
        }.frame(width: 76).background(Palette.deep)
            .overlay(alignment: .trailing) { Rectangle().fill(Palette.brass.opacity(0.13)).frame(width: 0.5) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(text: "Letter Studio   /   Correspondence").foregroundStyle(Palette.brass)
                TextField("Give this letter a name", text: $model.document.title)
                    .font(.custom("Baskerville", size: 34))
                    .foregroundStyle(Palette.cream).textFieldStyle(.plain).accessibilityLabel("Letter title")
            }
            Spacer(minLength: 20)
            Button { model.showPaper = true } label: { Label("Paper", systemImage: "doc") }
                .buttonStyle(StudioButton())
            Button { Task { await model.stopInput(); model.showFonts = true } } label: { Label("Fonts", systemImage: "textformat") }
                .buttonStyle(StudioButton())
            Button { Task { await model.edit() } } label: { Label("Edit", systemImage: "pencil.line") }
                .buttonStyle(StudioButton())
            Button {
                Task { await model.stopInput(); model.showPrint = true }
            } label: { Label("Print", systemImage: "printer") }
                .buttonStyle(StudioButton(filled: true))
        }
    }

    private var writingDesk: some View {
        GeometryReader { geometry in
            let paperWidth = min(560, geometry.size.width - 34, max(340, (geometry.size.height - 68) * model.layout.size.width / model.layout.size.height))
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 28) {
                        ForEach(model.layout.pages.indices, id: \.self) { index in
                            VStack(spacing: 13) {
                                HStack {
                                    SmallLabel(text: index == 0 ? "Personal letter" : "Continued")
                                    Spacer()
                                    Text(String(format: "%02d", index + 1)).font(.system(size: 10, design: .monospaced))
                                }.foregroundStyle(Palette.mist)
                                ZStack {
                                    Rectangle().fill(Color(hex: model.document.stationery.hex).opacity(0.75))
                                        .offset(x: 3, y: 4)
                                        .shadow(color: .black.opacity(0.15), radius: 2, y: 2)
                                    PaperView(layout: model.layout, page: index, width: paperWidth, visibleCharacters: model.visibleCharacters)
                                        .shadow(color: .black.opacity(0.25), radius: 22, x: 4, y: 16)
                                }.frame(width: paperWidth, height: paperWidth * model.layout.size.height / model.layout.size.width)
                                    .onTapGesture { Task { await model.edit() } }
                            }.frame(width: paperWidth).id(index)
                        }
                    }.frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
                }.scrollIndicators(.hidden)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(hex: 0x583331), Color(hex: 0x392526)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.brass.opacity(0.2), lineWidth: 0.7).padding(5))
                            .shadow(color: .black.opacity(0.25), radius: 12, x: 6, y: 10)
                    }
                    .onChange(of: model.layout.pages.count) { _, count in
                        if model.isBusy { withAnimation((reduceMotion || model.quietMode) ? nil : .easeInOut(duration: 0.3)) { scroll.scrollTo(count - 1, anchor: .bottom) } }
                    }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Button { Task { await model.toggleDictation() } } label: {
                HStack(spacing: 12) {
                    Image(systemName: model.isBusy ? "stop.fill" : "mic.fill").font(.system(size: 14))
                    Text(model.speech.state == .preparing ? "Preparing…" : model.speech.state == .finishing ? "Finishing…" : model.commandMode ? "Apply command" : model.isBusy ? "Finish dictation" : "Begin dictation")
                }.frame(minWidth: 137)
            }.buttonStyle(StudioButton(filled: true)).disabled(model.speech.state == .finishing)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.commandMode ? (model.commandTranscript.isEmpty ? "Say a command, then apply it." : model.commandTranscript) : model.speech.status)
                    .font(.system(size: 11)).foregroundStyle(Palette.cream.opacity(0.9)).lineLimit(2)
                Text(model.speech.state == .preparing ? "Preparing English dictation" : model.speech.state == .finishing ? "Finishing your last words" : model.isBusy ? "Your microphone is on · English" : "⇧⌘D  ·  On-device dictation")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.mist)
            }
            Spacer(minLength: 5)
            Button { model.panel = .voice } label: {
                Label("Voice edit", systemImage: "text.bubble").font(.system(size: 11))
            }.buttonStyle(.plain).foregroundStyle(Palette.mist)
                .help("Voice command: new paragraph, undo, read back, replace words, or print preview").accessibilityLabel("Voice command")
            if !model.document.text.isEmpty {
                Button {
                    if model.isReplaying { model.stopReplay() } else { Task { await model.replay() } }
                } label: { Image(systemName: model.isReplaying ? "pause" : "play").font(.system(size: 12)) }
                    .buttonStyle(.plain).foregroundStyle(Palette.mist).help("Replay the writing")
            }
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(model.document.wordCount) words  ·  \(model.layout.pages.count) \(model.layout.pages.count == 1 ? "page" : "pages")")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.mist)
                Text("\(model.document.paper.name)  /  \(model.document.handwriting.name)")
                    .font(.system(size: 9)).foregroundStyle(Palette.mist)
            }
        }
    }
}

struct GuideView: View {
    @Bindable var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ThreadMark(size: 35).foregroundStyle(Palette.accent)
            SmallLabel(text: "A small guide").foregroundStyle(Palette.muted)
            Text("Begin with something true.").font(.system(size: 31, design: .serif)).foregroundStyle(Palette.text)
            Text("Create a letter with New, then add a recipient and a few notes. Begin dictation to speak, or open Writing to type. Your words appear on the page as you go.")
            Text("Materials lets you choose handwriting, ink, and stationery. Print opens the preview, PDF export, and your Mac's print panel. Your reference notes and photographs stay off the printed page.")
            Text("For voice edits, open Voice edit, press Speak an edit, then Apply edit. You can also type an edit. Try “new paragraph”, “undo”, “read it back”, “print preview”, or “replace [words] with [new words]”.")
            Text("⌘N  New    ⌘E  Edit    ⇧⌘D  Dictate    ⌘P  Print    ⌘S  Save")
                .font(.system(size: 11, design: .monospaced))
            Divider()
            Text("Letters and photos are stored on this Mac. Dictation uses Apple's on-device English model; its first use may download the model. You can export a .letter file from the File menu to keep an additional copy.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            Button("Back to your letter") { model.showGuide = false }.buttonStyle(.borderedProminent).tint(Palette.text)
        }.font(.system(size: 13)).lineSpacing(5).foregroundStyle(Palette.text)
            .padding(40).frame(width: 570).background(Palette.cream)
    }
}

struct LibraryView: View {
    @Bindable var model: StudioModel
    @State private var query = ""
    private var letters: [LetterDocument] {
        model.library.filter { query.isEmpty || ($0.title + $0.recipient + $0.text).localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    SmallLabel(text: "Letter Studio / The archive").foregroundStyle(Palette.brass)
                    Text("Correspondence.").font(.custom("Baskerville", size: 46)).foregroundStyle(Palette.cream)
                    Text("The people, the days, the things you wanted to say.")
                        .font(.custom("Baskerville-Italic", size: 18)).foregroundStyle(Palette.mist)
                }
                Spacer()
                Button("Back", systemImage: "arrow.left") { model.showLibrary = false }.buttonStyle(StudioButton())
                Button("New letter", systemImage: "plus") { Task { await model.newLetter() } }.buttonStyle(StudioButton(filled: true))
            }.padding(.bottom, 34)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.mist)
                ZStack(alignment: .leading) {
                    if query.isEmpty {
                        Text("Find a letter or a person").foregroundStyle(Palette.mist).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextField("", text: $query).textFieldStyle(.plain).foregroundStyle(Palette.cream)
                        .accessibilityLabel("Search letters")
                }.font(.custom("AvenirNext-Regular", size: 13))
                Spacer()
                SmallLabel(text: "\(letters.count) \(letters.count == 1 ? "letter" : "letters")").foregroundStyle(Palette.mist)
            }.padding(.vertical, 18)
            Rectangle().fill(Palette.brass.opacity(0.3)).frame(height: 0.5)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if letters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("No letters found.").font(.custom("Baskerville", size: 30))
                            Text("Try another name or a few words from the letter.").font(.system(size: 13))
                            Button("Clear search") { query = "" }.buttonStyle(StudioButton())
                        }.foregroundStyle(Palette.cream).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 50)
                    }
                    ForEach(Array(letters.enumerated()), id: \.element.id) { index, letter in
                        ArchiveRow(letter: letter, index: index) { Task { await model.select(letter) } }
                    }
                }
            }.scrollIndicators(.visible)
        }.padding(40).background { DeskBackground() }
    }
}

private struct ArchiveRow: View {
    let letter: LetterDocument
    let index: Int
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                Text(String(format: "%02d", index + 1)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.brass)
                PaperView(layout: LetterLayout(document: letter), width: 85, decoration: false)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                    .padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 9) {
                    Text(letter.title).font(.custom("Baskerville", size: 27)).foregroundStyle(Palette.cream).lineLimit(1)
                    Text(letter.recipient.isEmpty ? "No recipient yet" : "To \(letter.recipient)")
                        .font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(Palette.mist).lineLimit(1)
                    Text(String(letter.text.replacingOccurrences(of: "\n", with: " ").prefix(120)))
                        .font(.custom("Baskerville-Italic", size: 14)).foregroundStyle(Palette.mist).lineLimit(2)
                        .frame(maxWidth: 480, alignment: .leading)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 14) {
                    Text(letter.updatedAt, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.mist)
                    Image(systemName: "arrow.up.right").font(.system(size: 18, weight: .light)).foregroundStyle(Palette.brass)
                }
            }.padding(.vertical, 22).padding(.horizontal, 12)
                .contentShape(Rectangle())
                .background(Color.white.opacity(hovered ? 0.04 : 0))
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.brass.opacity(0.2)).frame(height: 0.5) }
        }.buttonStyle(.plain).onHover { hovered = $0 }.accessibilityLabel("Open \(letter.title)")
    }
}

struct PrintPreview: View {
    @Bindable var model: StudioModel
    var body: some View {
        HStack(spacing: 32) {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(model.layout.pages.indices, id: \.self) { index in
                        PaperView(layout: model.layout, page: index, width: 350, decoration: false)
                    }
                }.padding(20)
            }.frame(width: 390).background(Color(hex: 0xD6DCD4))
            VStack(alignment: .leading, spacing: 24) {
                SmallLabel(text: "From screen to paper").foregroundStyle(Palette.muted)
                Text("From you,\nwith love.").font(.custom("Baskerville", size: 42)).foregroundStyle(Palette.text)
                Text("\(model.layout.pages.count) \(model.layout.pages.count == 1 ? "page" : "pages") · \(model.document.paper.name) · Actual size")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                Toggle("Include paper color & texture", isOn: $model.includePaperColor).font(.system(size: 12)).tint(Palette.text)
                Text(model.includePaperColor ? "Your PDF includes the selected paper color. Printers may leave a white border." : "Only the ink will print. Load your own stationery to match the paper shown here.")
                    .font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.muted)
                Spacer()
                Button { model.printLetter() } label: {
                    Label("Choose printer…", systemImage: "printer").frame(maxWidth: .infinity)
                }.buttonStyle(FolioButton(primary: true))
                Button { model.exportPDF() } label: { Label("Save PDF…", systemImage: "arrow.down.document").frame(maxWidth: .infinity) }.buttonStyle(FolioButton())
                Button("Back to writing") { model.showPrint = false }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.padding(.vertical, 30).frame(width: 245)
        }.padding(24).background(Palette.cream).frame(width: 760, height: 650)
    }
}
