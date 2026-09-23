# HerLetterStudio

A native Mac app for writing letters the way *Her* imagines it: speak or type your own words, watch them appear in handwriting on real-looking paper, then export or print the finished page. Dictation runs on-device. No account, no cloud, no paid API.

Requires macOS 26.

## Try it in 5 minutes

No microphone needed — start with the guided sample:

1. Build and open the app (see [Build](#build)), then click **Demo** in the left rail.
2. Click **Open the sample letter**. This creates "Twenty-eight ordinary years": a fictional anniversary letter with a client brief, two credited reference photos, Parisienne lettering, sepia ink, and a one-page print layout. Your current letter is saved first.
3. In the sample Context folio, click **Watch** to replay the ink reveal without a microphone, **Try an edit** for a prepared voice-edit instruction (then Apply instruction), or **Print** for the real output preview.

You now have a saved sample in Letters. Reopening it later keeps the letter and photos; Demo always opens a fresh copy. Next step: write your own below.

## Write your own letter

1. Open the app and choose **New**. In **Context**, add a recipient, occasion, notes, or reference photos.
2. Press the microphone button and allow microphone access when asked. English recognition runs on-device; Apple may download speech assets on first use. Press again to finish.
3. Fix wording in **Writing/Edit**. **Fonts** opens a specimen book: pick a style from the index, then Edit sample text to try your own words. **Expression** offers Tender, Familiar, and Reflective hands, a resonance control, five inks, and stationery; expand Lettering & size for font size and pick Letter/A4 below.
4. Correct hands-free in **Voice Edit**: press Speak an edit, say the instruction, then Apply edit — or type it and Apply instruction. Recognized instructions and feedback stay visible. Plain speech here is treated as letter text, not a command.
5. Open **Print** to review every page, save a PDF, or print through the native Mac panel. Enable paper color to print the stationery tint; leave it off when using colored paper.

Tip: the small play triangle beside Voice edit replays the ink reveal on any populated letter without changing your words.

## Voice edits

Say or type these in Voice Edit. Phrase edits need exactly one match — ambiguous edits leave the text unchanged and explain why.

| Instruction | Effect |
|---|---|
| “Replace afternoon with evening” / “Change afternoon to evening” | Replace a phrase |
| “Delete by the water” | Delete a phrase |
| “Insert beautiful before afternoon” / “Insert forever after love” | Insert a word |
| “Delete the last sentence” / “Delete the last paragraph” | Delete a block |
| “New paragraph” | Break the paragraph |
| “Use Baskerville” / “Change font to Daydream” | Change hand |
| “Set font size to 22” / “Make it bigger” / “Make it smaller” | Change size |
| “Undo the last change” / “Redo” | Step through history |
| “Read it back” / “Print preview” | Read aloud / open review |

Expression-only phrases (“a little more tender”, “less formal”, “more reflective”, “more restrained”, “more expressive”, “change ink to oxblood sincerity”) change presentation, never wording. “Send to the writing desk” opens print review. The panel shows each change with undo/redo — up to 50 revisions per letter, including font, size, ink, and expression. Undo history is session-local and clears when you switch letters.

## Letters, drafts, and files

- Drafts autosave locally under `~/Library/Application Support/HerLetterStudio`.
- **Letters** reopens drafts: sort by title or recent edit, right-click to duplicate or move to **Recently Removed**, recover from that collection, and rename by editing the title above the paper.
- **Drafts** in the bottom bar keeps named versions across launches; restoring keeps a safety copy of your current letter first. Versions stay on this Mac — export a `.letter` file (File menu, references included) for an independent backup.
- Failed saves keep the current document open for recovery.

## Paper, hands, and quiet

- **Paper** opens a stationery drawer (Cotton Rag, Laid, Vellum, Onion Skin, Cream Bond). The material saves with the letter, supports undo, and printing defaults to ink only — tick **Include paper color & texture** to print the same procedural surface you see on screen. Material names describe visual textures, not certified paper stock.
- **Fonts** holds eleven styles: seven bundled licensed handwriting fonts (La Belle Aurore, Caveat, Nothing You Could Do, Bad Script, Reenie Beanie, Sacramento, Parisienne) plus Baskerville, Georgia, Palatino, and American Typewriter. Search names and descriptive words (try “romantic” or “slanted”); star hands and enable **Favorites only** to narrow the collection. Search is a text filter, not emotion analysis. Provenance and checksums: `Sources/LetterCore/Resources/Fonts/SOURCES.md`.
- **Quiet** in the rail finishes visible ink animation at once, stops readback, and suppresses further reveal motion. Dictation still updates the page immediately. The preference persists and complements macOS Reduce Motion. No sound effects.
- Zoom (Fit, Fit Width, percentages, page menu, pinch, ⌘−/⌘=/⌘0) never changes print size. Follow dictation is off by default. Each page's **Edit text** opens a larger editor at that passage.

## How it works

Screen and PDF share one Core Text page layout, so what you see is what prints — exported text stays selectable. Reference photos inform the writing and are never printed, nor are UI decorations. Expression (hands, resonance, ink) adjusts spacing, pacing, and color of font-based rendering; it does not synthesize pen strokes, infer emotion, or drive hardware. It is not a learned copy of your handwriting either.

## Build

```sh
bash scripts/test.sh        # core checks: dictation, pagination/PDF, storage, commands
bash scripts/build-app.sh   # ad-hoc signed local app (not notarized)
open 'build/HerLetterStudio.app'
```

Deeper verification (screenshots land under `build/`):

```sh
bash scripts/verify-app.sh              # app checks + window snapshots
bash scripts/verify-app.sh voice        # recorded-speech recognition
bash scripts/verify-app.sh voice-edit   # spoken edit instructions
bash scripts/verify-app.sh interaction  # fixed-window click/type smoke test (isolated window; never touches your drafts or microphone)
bash scripts/verify-app.sh microphone   # real microphone capture
bash scripts/verify-app.sh transition transition-scripted  # repeatable workspace drive; append an audio path to use recorded speech
```

Honest limits: the build is ad-hoc signed, not a notarized public distribution. A physical printer was never configured during development — PDF dimensions and the print-preview path were checked, but paper output and your own dictation accuracy still need a hands-on trial.

## Docs map

| Doc | What it answers |
|---|---|
| `SPEC.md` | What was built, and the exact build/verify commands |
| `DESIGN.md` | The visual thesis and review decisions |
| `research/FINDINGS.md` | Film references and sources |
| `LONGHAND.md` | Feasibility map: software, research, and hardware boundaries |
| `PRINTER.md` | Printer shortlist, paper limits, store-integration findings |
| `WORKFLOW-AUDIT.md` | Remaining limitations and verification coverage |
| `PROGRESS.md` | Build history and what's next |
