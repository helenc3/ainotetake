# MVP — AI Lecture Note Taker

One static file. No build, no backend, no dependencies.

## What ships

**`index.html`** — the whole app.

1. **Record** — `SpeechRecognition` streams live transcript to the page.
   Auto-restarts on the browser's periodic cutoff so a 90-minute lecture stays intact.
2. **Generate notes** — one `POST` to an OpenAI-compatible `/chat/completions`
   endpoint with a prompt that asks for: `## Summary`, `## Key points`,
   `## Terms & definitions`, `## Action items` — and explicitly forbids inventing
   facts not in the transcript.
3. **Copy** — markdown to clipboard.

## Providers

Picked from a dropdown; key stored per-provider in `localStorage`, never sent anywhere else.

| Provider | Model | Cost |
|---|---|---|
| Groq (default) | `llama-3.3-70b-versatile` | free key |
| Google Gemini | `gemini-2.0-flash` | free key |
| OpenRouter | `llama-3.3-70b-instruct:free` | free key |
| Ollama | `llama3.1` | none — fully local, no key |

Ollama only works when the page itself is on `http://localhost` (an HTTPS page
can't call a local HTTP server).

## Run it

```sh
python3 -m http.server 8000   # then open http://localhost:8000
node test.js                  # self-check for the markdown renderer
```

Use `localhost`, not `file://` — the microphone needs a secure context.

Deployed: https://helenc3.github.io/ainotetake/

## Deliberately skipped

| Skipped | Add when |
|---|---|
| Backend / key proxy | The app leaves your machine and has real users |
| Whisper (transformers.js) transcription | Chrome's recognizer mangles your lecturer, or you need Firefox |
| Multiple saved lectures | Current build keeps one transcript + notes in localStorage across reloads; add a session list when one isn't enough |
| Markdown library | The 8-line renderer in `md()` stops being enough |
| Streaming notes as they generate | A lecture's worth of notes takes long enough to feel slow |
