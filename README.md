# Letter Studio

A native Mac letter-writing workspace inspired by the office scenes in *Her*. Speak or type your own words, watch them appear in handwriting, and export or print the finished page.

Requires macOS 26. The built app is at `build/Letter Studio.app`.

## Use

1. Open the app and choose New. Add a recipient, occasion, notes, or reference photos in Context.
2. Press the microphone button and allow microphone access. English speech recognition runs on device; Apple may download speech assets on first use. Press again to finish the last words.
3. Use Writing/Edit to correct text. Fonts opens a gallery with previews using your own sample text. Materials controls size, ink, stationery, and Letter/A4 paper.
4. Open Voice Edit and press Speak an edit, speak, then Apply edit. Or type the same instruction and click Apply typed edit. Recognized instructions and edit feedback remain visible. Ordinary dictation is treated as letter text.
5. Open Print to review every page, save a PDF, or choose a printer in the native Mac panel. Enable paper color to print the stationery tint; leave it off when using colored paper.

To try the writing animation without speaking, open any populated letter and click the small play triangle beside Voice edit. This replays the ink reveal without changing your words.

Drafts autosave locally under `~/Library/Application Support/Letter Studio`. The Letters view reopens drafts; the File menu imports/exports portable `.letter` files including references. Failed saves keep the current document open for recovery.

The seven lettering styles include three bundled, licensed handwriting fonts (La Belle Aurore, Caveat, Nothing You Could Do), plus the Mac’s Baskerville, Georgia, Palatino, and American Typewriter. It is not a learned copy of your handwriting. Screen and PDF share the same Core Text page layout; exported text stays selectable. References and UI decorations are not printed.

## Build and verify

```sh
bash scripts/test.sh
bash scripts/build-app.sh
bash scripts/verify-app.sh
bash scripts/verify-app.sh voice
bash scripts/verify-app.sh voice-edit
bash scripts/verify-app.sh microphone
open 'build/Letter Studio.app'
```

The build script creates an ad-hoc signed local app. This is not a notarized public distribution.

Checks cover pagination and exact PDF text across all styles/paper sizes, document round trips and schema rejection, command parsing, transcript reconciliation, save-failure recovery, speech startup cancellation, recorded speech recognition, concurrent stopping, and real microphone capture. UI snapshots are written under `build/`.

A physical printer was not configured during development. PDF dimensions and the native print-preview path were checked; paper output and your own spoken dictation accuracy still need a hands-on trial. No cloud account or paid API is required.

See `research/FINDINGS.md` for film references and sources. Font licenses ship beside the bundled fonts in `Sources/LetterCore/Resources/Fonts`.

## Transition QA

`bash scripts/verify-app.sh transition transition-scripted` drives the visible workspace with repeatable partial transcripts, including a capitalization correction and line wrapping. To use recorded speech instead, append an absolute audio-file path. These runs use an in-memory draft and never request microphone access. Frames, cursor samples, and the final transcript are saved under `build/`. Screen capture affects timing, so the CSV is a continuity diagnostic, not a frame-rate benchmark.

## Voice editing

Speak or type these instructions in Voice Edit:

- “Replace afternoon with evening” or “Change afternoon to evening”
- “Delete by the water”
- “Insert beautiful before afternoon” or “Insert forever after love”
- “Delete the last sentence” / “Delete the last paragraph”
- “New paragraph”
- “Use Baskerville” / “Change font to Daydream”
- “Set font size to 22” / “Make it bigger” / “Make it smaller”
- “Undo the last change” / “Redo”
- “Read it back” / “Print preview”

Phrase edits require exactly one matching phrase; ambiguous edits leave the text unchanged and explain why. The panel shows the changed text and offers undo/redo, with up to 50 revisions for the current letter. Font changes and size changes participate in the same history. Undo history is session-local; it is cleared when switching letters. These are supported editing instructions, not open-ended generative rewriting.
