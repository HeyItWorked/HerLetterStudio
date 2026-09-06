import AppKit
import LetterCore

/// Drives the real workspace without microphone access or persistent drafts.
@MainActor enum TransitionQA {
    static func run(model: StudioModel, window: NSWindow, directory: URL, audio: URL?) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        model.document.text = ""
        try await Task.sleep(for: .milliseconds(300))
        let feed = Task {
            if let audio {
                await model.speech.start(audioFileURL: audio) { model.receiveDictation($0) }
            } else {
                for text in ["dear Alex", "Dear Alex,", "Dear Alex, I remember the afternoon",
                             "Dear Alex, I remember the afternoon by the water.",
                             "Dear Alex, I remember the afternoon by the water. The light was warm",
                             "Dear Alex, I remember the afternoon by the water. The light was warm and the air was quiet."] {
                    model.receiveDictation(text)
                    try? await Task.sleep(for: .milliseconds(650))
                }
            }
        }
        var rows = ["seconds,visible,target"]
        let start = ProcessInfo.processInfo.systemUptime
        for index in 0..<150 {
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            rows.append("\(elapsed),\(model.visibleCharacters.map { Double($0) } ?? Double(model.document.text.utf16.count)),\(model.document.text.utf16.count)")
            if let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.75])?.write(to: directory.appendingPathComponent(String(format: "%04d.jpg", index)))
            }
            try await Task.sleep(for: .milliseconds(33))
        }
        await feed.value
        await model.speech.stop()
        try rows.joined(separator: "\n").write(to: directory.appendingPathComponent("timing.csv"), atomically: true, encoding: .utf8)
        try model.document.text.write(to: directory.appendingPathComponent("transcript.txt"), atomically: true, encoding: .utf8)
        print("PASS: workspace transition captured to \(directory.path)")
    }
}
