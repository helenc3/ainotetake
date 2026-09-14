# MVP — AI Lecture Note Taker

Two ways to run this: a native macOS app (primary) and a static
web page (fallback, shipped).

## macOS app (primary — builds and launches)

**`mac/`** — SwiftUI, SwiftPM executable, macOS 14+, no third-party
dependencies.

- `mac/Package.swift` — package manifest
- `mac/Sources/NoteTaker/NoteTakerApp.swift` — app entry point
- `mac/Sources/NoteTaker/ContentView.swift` — UI (record button, transcript/notes panes, copy, clear)
- `mac/Sources/NoteTaker/Transcriber.swift` — `SFSpeechRecognizer` + `AVAudioEngine`, on-device when supported, auto-restarts the recognition session under the hood (the API caps a session at ~1 minute) so one click covers a 90-minute lecture
- `mac/Sources/NoteTaker/Notes.swift` — note generation, same four OpenAI-compatible providers as the web app
- `mac/Resources/Info.plist` — declares `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`
- `mac/build.sh` — builds `Lecture Notes.app` and ad-hoc codesigns it

Transcript and notes persist across app relaunches. API keys are stored per
provider in `UserDefaults`, never transmitted anywhere but to the chosen
provider.

### Build / run

```sh
cd mac && ./build.sh --run
```

Builds via `swift build -c release`, packages `Lecture Notes.app`, ad-hoc
codesigns it, and launches it.

### Limits

- Not notarized, not Developer ID signed — ad-hoc codesign only. Gatekeeper
  will warn or block on any machine but the one that built it; right-click →
  Open to bypass, or build it yourself.
- Compiles clean and launches; not yet tested against a real lecture — treat transcription quality as unverified. The auto-restart path's bookkeeping is covered by `node test.js` (web) and was fixed on both platforms, but no test drives real audio through it.
- macOS 14+ only; no Windows/Linux/iOS build.

## Web app (fallback — shipped)

One static file. No build, no backend, no dependencies.

**`index.html`** — the whole app.

1. **Record** — `SpeechRecognition` streams live transcript to the page.
   Auto-restarts on the browser's periodic cutoff so a 90-minute lecture stays intact.
2. **Generate notes** — one `POST` to an OpenAI-compatible `/chat/completions`
   endpoint with a prompt that asks for: `## Summary`, `## Key points`,
   `## Terms & definitions`, `## Action items` — and explicitly forbids inventing
   facts not in the transcript.
3. **Copy** — markdown to clipboard.

### Providers

Picked from a dropdown; key stored per-provider in `localStorage`, never sent anywhere else.

| Provider | Model | Cost |
|---|---|---|
| Groq (default) | `llama-3.3-70b-versatile` | free key |
| Google Gemini | `gemini-2.0-flash` | free key |
| OpenRouter | `llama-3.3-70b-instruct:free` | free key |
| Ollama | `llama3.1` | none — fully local, no key |

Ollama only works when the page itself is on `http://localhost` (an HTTPS page
can't call a local HTTP server).

### Run it

```sh
python3 -m http.server 8000   # then open http://localhost:8000
node test.js                  # self-check: markdown renderer + the ~60s restart path
```

Use `localhost`, not `file://` — the microphone needs a secure context.

Deployed: https://helenc3.github.io/ainotetake/

### Limits

- Speech recognition runs through the browser's Web Speech API — audio goes
  to the browser vendor's servers, not on-device, and doesn't work offline.
- ~60s recognition session cutoff, worked around with auto-restart (can lose
  a few hundred ms of audio at each restart boundary).
- Chrome/Edge/Safari only; quality varies by accent.
- Lives in a browser tab — closing it or letting the laptop sleep can kill
  the recording.

## Deliberately skipped (both)

| Skipped | Add when |
|---|---|
| Backend / key proxy | The app leaves your machine and has real users |
| Notarized / Developer ID signed Mac build | Distributing to anyone besides the developer |
| Mac App Store distribution | Never planned for v1; would need sandboxing review |
| Whisper (transformers.js or native) transcription | The platform recognizer mangles your lecturer, or you need cross-platform parity |
| Multiple saved lectures | Current build keeps one transcript + notes persisted across reloads/relaunches; add a session list when one isn't enough |
| Markdown library | The small hand-rolled renderer stops being enough |
| Streaming notes as they generate | A lecture's worth of notes takes long enough to feel slow |
| Windows/Linux native app | There's demand outside macOS |
