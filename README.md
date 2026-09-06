# Letter Studio

A native Mac letter-writing workspace inspired by the office scenes in *Her*. Speak or type your own words, watch them appear in handwriting, and export or print the finished page.

Requires macOS 26. The built app is at `build/Letter Studio.app`.

## Use

1. Open the app and choose New. Add a recipient, occasion, notes, or reference photos in Context.
2. Press the microphone button and allow microphone access. English speech recognition runs on device; Apple may download speech assets on first use. Press again to finish the last words.
3. Use Writing/Edit to correct text. Fonts opens a specimen book: choose a style from the index, then click Edit sample text to try your own words. Expression offers Tender, Familiar, and Reflective hands, a resonance control, five inks, and stationery. Expand Lettering & size for font size; choose Letter/A4 below.
4. Open Voice Edit and press Speak an edit, speak, then Apply edit. Or type the same instruction and click Apply instruction. Recognized instructions and edit feedback remain visible. Ordinary dictation is treated as letter text.
5. Open Print to review every page, save a PDF, or choose a printer in the native Mac panel. Enable paper color to print the stationery tint; leave it off when using colored paper.

To try the writing animation without speaking, open any populated letter and click the small play triangle beside Voice edit. This replays the ink reveal without changing your words.

Drafts autosave locally under `~/Library/Application Support/Letter Studio`. The Letters view reopens drafts; the File menu imports/exports portable `.letter` files including references. Failed saves keep the current document open for recovery.

The eleven lettering styles include seven bundled, licensed handwriting fonts (La Belle Aurore, Caveat, Nothing You Could Do, Bad Script, Reenie Beanie, Sacramento, Parisienne), plus the Mac’s Baskerville, Georgia, Palatino, and American Typewriter. It is not a learned copy of your handwriting. Screen and PDF share the same Core Text page layout; exported text stays selectable. References and UI decorations are not printed.

## Build and verify

```sh
bash scripts/test.sh
bash scripts/build-app.sh
bash scripts/verify-app.sh
bash scripts/verify-app.sh voice
bash scripts/verify-app.sh voice-edit
bash scripts/verify-app.sh interaction
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

## Design and interaction checks

The correspondence desk uses a fixed dictation bar, an ivory reference folio, an eleven-style specimen book, and a row-based archive. Focus hides the folio. Hover/press feedback and spatial transitions respect Reduce Motion. See `DESIGN.md` for the visual thesis and review decisions.

The optional `interaction` verifier clicks and types in an isolated native window. It checks font selection across a row, editing the specimen, opening/searching/reopening the archive, and saves screenshots of the typed specimen and empty search results. It is a fixed-window mouse/text smoke test, not a complete keyboard or VoiceOver audit. It does not open your saved drafts or request the microphone.

## Longhand Console exploration

Open **Expression**, choose a hand, adjust **Resonance**, and click **Watch the ink**. Scroll down for the five inks and paper. Voice Edit accepts “a little more tender”, “less formal”, “more reflective”, “more restrained”, “more expressive”, and “change ink to oxblood sincerity”. These change presentation, not wording. “Send to the writing desk” opens print review.

Expression settings are saved with each letter and support undo/redo. Reset removes expression spacing/pacing while keeping your font and ink. This remains font-based rendering: it does not synthesize real pen strokes, infer emotion, or control a calligraphy robot. See [the feasibility map](LONGHAND.md) for the narrative's software, research, and hardware boundaries.

The four new internet-sourced hands appear first in Fonts. Try Bad Script for a personal letter, Reenie Beanie for a spontaneous note, Sacramento for fine cursive, or Parisienne for a romantic flourish. Scroll the collection for the original styles. Font provenance and checksums are in `Sources/LetterCore/Resources/Fonts/SOURCES.md`.

## Try the complete photographic walkthrough

Click **Demo** in the left rail, then **Open the sample letter**. This creates “Twenty-eight ordinary years”: an original fictional anniversary letter with a client brief, two credited Unsplash reference photographs, Parisienne lettering, sepia ink and a one-page print layout. Your current letter is saved first.

In the sample Context folio, click **Watch** to replay the writing without a microphone; **Try an edit** opens a prepared instruction (click Apply instruction); **Print** opens the actual output preview. Photographs inform the writing and are not printed. The editable sample is saved in Letters. Reopening it later retains the letter and photos; Demo opens another fresh copy with the walkthrough controls.

See [PRINTER.md](PRINTER.md) for the Amazon printer shortlist, paper limits and Amazon integration findings.

## The Writing Room

The desk now uses warm walnut, brass accents and an oxblood writing pad. **Paper** opens a stationery drawer with Cotton Rag, Laid, Vellum, Onion Skin and Cream Bond surface previews. The material is saved with the letter and supports undo. Printing defaults to ink only; **Include paper color & texture** includes the same procedural surface used on screen. The material names describe visual textures, not physical paper certification.

**Fonts** now searches names and descriptive words (try “romantic”, “slanted” or “familiar”). Star a hand and enable **Favorites only** to narrow the collection. Favorites persist on this Mac. Search is a text filter, not semantic emotion analysis.

**Quiet** in the rail immediately finishes visible ink animation, stops current readback, and suppresses subsequent reveal/transition motion. Dictation still updates the page immediately; explicit Read aloud remains available. This preference persists and complements macOS Reduce Motion. No decorative sound effects are added.

### Navigation and revisions

Use the control strip above the paper for Fit, Fit Width, percentages, or the page menu. Pinch to zoom; ⌘− / ⌘= zoom and ⌘0 fits the page. Zoom does not change printing size. Follow dictation is off by default; enable the trailing follow control to move to newly created pages.

Each page's **Edit text** opens a larger editor at that passage. **Drafts** in the bottom bar keeps named versions across launches; restoring keeps a safety copy of the current letter first. These versions stay on this Mac. Export a `.letter` file for an independent backup.

In **Letters**, sort by title or recent edit, and right-click to duplicate or move a letter to **Recently Removed**. Select that collection in the archive menu and click a letter to recover it. To rename a letter, open it and edit the title above the paper.

The print preview now shows the generated PDF, including the paper color/texture option. Load the matching paper size and use 100% scale in the Mac print panel. See [the workflow audit](WORKFLOW-AUDIT.md) for remaining limitations and verification coverage.
