import AVFoundation
import Speech
import Observation

@MainActor @Observable final class SpeechController {
    enum State { case idle, preparing, listening, finishing }
    var state: State = .idle
    var status = "Your words, in your own time."
    var error: String?
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var startupID = UUID()
    private var finalText = ""
    private var output: ((String) -> Void)?
    private var stopTask: Task<Void, Never>?
    private var tapInstalled = false
    private var audioBridge: AudioBridge?
    func start(output: @escaping (String) -> Void) async {
        guard state == .idle else { return }
        let id = UUID()
        startupID = id
        state = .preparing
        status = "Preparing your microphone…"
        error = nil
        self.output = output
        finalText = ""
        print("speech start")
        do {
            let allowed = await AVCaptureDevice.requestAccess(for: .audio)
            guard id == startupID else { return }
            guard allowed else { throw VoiceError.message("Allow microphone access in System Settings → Privacy & Security → Microphone, then try again.") }
            guard SpeechTranscriber.isAvailable,
                  let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
                throw VoiceError.message("On-device English dictation isn't available on this Mac. You can still write with the keyboard.")
            }
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                status = "Downloading Apple's on-device speech model…"
                try await installation.downloadAndInstall()
            }
            guard id == startupID else { return }
            let engine = AVAudioEngine()
            let sourceFormat = engine.inputNode.outputFormat(forBus: 0)
            guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0,
                  let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: sourceFormat) else {
                throw VoiceError.message("No usable microphone was found. Check your Mac's sound input settings.")
            }
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            try await analyzer.prepareToAnalyze(in: format)
            guard id == startupID else { await analyzer.cancelAndFinishNow(); return }
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            let bridge = try AudioBridge(source: sourceFormat, target: format, continuation: continuation)
            audioBridge = bridge
            self.engine = engine
            self.analyzer = analyzer
            self.continuation = continuation
            resultTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        guard let self, self.startupID == id else { return }
                        let text = String(result.text.characters)
                        if result.isFinal {
                            self.finalText += text
                            self.output?(self.finalText)
                        } else {
                            self.output?(self.finalText + text)
                        }
                    }
                } catch {
                    guard let self, self.startupID == id, self.state != .idle else { return }
                    self.error = "Dictation stopped: \(error.localizedDescription). Your visible words have been kept."
                    Task { await self.stop() }
                }
            }
            try await analyzer.start(inputSequence: stream)
            guard id == startupID else {
                continuation.finish()
                await analyzer.cancelAndFinishNow()
                return
            }
            engine.inputNode.installTap(onBus: 0, bufferSize: 2048, format: sourceFormat, block: bridge.makeTap())
            tapInstalled = true
            engine.prepare()
            try engine.start()
            state = .listening
            status = "Listening. Speak naturally."
        } catch {
            guard id == startupID else { return }
            self.error = error.localizedDescription
            await stop()
        }
    }
    func stop() async {
        if let stopTask { await stopTask.value; return }
        guard state != .idle else { return }
        let task = Task { await finishSession() }
        stopTask = task
        await task.value
    }
    private func finishSession() async {
        if state == .preparing {
            startupID = UUID()
        }
        state = .finishing
        status = "Finishing your last words…"
        if let engine {
            engine.stop()
            if tapInstalled { engine.inputNode.removeTap(onBus: 0) }
        }
        tapInstalled = false
        engine = nil
        audioBridge = nil
        continuation?.finish()
        continuation = nil
        if let analyzer {
            do { try await analyzer.finalizeAndFinishThroughEndOfInput() }
            catch { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
        await resultTask?.value
        resultTask = nil
        output = nil
        stopTask = nil
        state = .idle
        status = "Your words, in your own time."
    }
}

enum VoiceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { text } else { nil } }
}

/// Used exclusively on AVAudioEngine's serial input callback. Each converted buffer
/// is freshly allocated before ownership is passed into the analyzer's stream.
private final class AudioBridge: @unchecked Sendable {
    let converter: AVAudioConverter
    let target: AVAudioFormat
    let continuation: AsyncStream<AnalyzerInput>.Continuation
    init(source: AVAudioFormat, target: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) throws {
        guard let converter = AVAudioConverter(from: source, to: target) else {
            throw VoiceError.message("The microphone's audio format couldn't be converted.")
        }
        self.converter = converter
        self.target = target
        self.continuation = continuation
    }
    // Create this callback outside MainActor: AVAudioEngine invokes it on its audio queue.
    func makeTap() -> AVAudioNodeTapBlock {
        { [self] buffer, _ in consume(buffer) }
    }
    func consume(_ buffer: AVAudioPCMBuffer) {
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate)) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        let input = SingleBuffer(buffer)
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, state in
            if input.consumed { state.pointee = .noDataNow; return nil }
            input.consumed = true
            state.pointee = .haveData
            return input.buffer
        }
        if status != .error, converted.frameLength > 0 {
            continuation.yield(AnalyzerInput(buffer: converted))
        }
    }
}

private final class SingleBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var consumed = false
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
}
