# PRD — AI Lecture Note Taker

**Status:** macOS app builds + launches, web app v0 shipped · **Owner:** Helen · **Last updated:** 2026-09-14

## Problem

Students can either listen to a lecture or write it down, not both. Existing
tools (Otter, Notion AI) require an account, a subscription, and uploading
recordings of someone else's class to a third-party server.

## Users

Primary: a student in a live lecture with a Mac open.
Secondary: anyone in a long meeting who wants structured notes, not a transcript.

## Goals

1. Zero setup friction to try it — the web app is a URL, click record, get notes, no signup.
2. For regular use, a real app: on-device transcription, no browser tab to babysit, notes survive quitting and relaunching.
3. Notes are *structured* (summary, key points, terms, action items), not a wall of text.
4. Free to run. Free-tier API key, or fully local (transcription is always local on the Mac app; note generation can be too, via Ollama).

## Non-goals (v1)

- Accounts, sync, or a backend of any kind
- Storing or replaying audio
- Multi-speaker diarization, slides/PDF ingestion, real-time notes while recording
- iOS/mobile app
- Mac App Store distribution, notarization, or a Developer ID signature — the
  app is ad-hoc signed for local use only
- Windows/Linux native app

## Requirements

| # | Requirement | Status |
|---|---|---|
| R1 | Capture live speech to text, hands-free, for a full lecture (60–90 min) | ✅ web (auto-restart hack) · 🚧 native |
| R2 | Transcription happens on-device — audio never leaves the machine | 🚧 native (Speech framework, on-device when supported) — web app sends audio to the browser's Speech API, not local |
| R3 | Turn the raw transcript into structured markdown notes on demand | ✅ web · 🚧 native (same 4-provider prompt) |
| R4 | Work with a free API key; user picks the provider | ✅ web · 🚧 native |
| R5 | Option to run with no key and no data leaving the machine (Ollama) | ✅ web · 🚧 native |
| R6 | Fully offline operation (transcription + notes) when paired with Ollama | ➖ not possible in browser (Speech API needs network) · 🚧 native (on-device speech + local Ollama = fully offline) |
| R7 | Copy notes out to any other app | ✅ web · 🚧 native |
| R8 | Transcript and notes survive an accidental reload / app relaunch | ✅ web (localStorage) · 🚧 native (persists across relaunch) |
| R9 | Never transmit or persist the API key beyond the user's own machine | ✅ web (localStorage) · 🚧 native (UserDefaults, per provider) |
| R10 | Show a clear error when the mic/speech permission is denied or the API rejects the call | ✅ web · 🚧 native |
| R11 | No install-time friction: zero-install fallback always available | ✅ web app stays live as the no-install path |

## Success metrics

- A 60–90 minute lecture, recorded in one uninterrupted session, produces usable notes in one click, under 30s.
- Zero cost per user at the free tiers.
- Time-to-first-note for a new user: under 2 minutes including getting a key (web), or under 5 minutes including the first build (native).
- Native app: a 90-minute recording completes without the user touching record more than once, and without the session dropping.

## Why native

The browser version works but fights the platform: the Web Speech API sends
audio to Google/Apple servers over the network, caps a recognition session at
roughly a minute (worked around with an auto-restart hack), and lives in a
tab a student can accidentally close or that sleeps when the laptop lid
issues. The macOS app fixes all four by using Apple's on-device Speech
framework directly: no audio leaves the machine, it works fully offline when
paired with local Ollama, there's no ~60s cutoff to work around, and it's a
real app with an icon and a window meant to be left running for an hour,
not a tab.

## Risks

| Risk | Mitigation |
|---|---|
| Web Speech API is Chrome/Edge/Safari only, quality varies by accent | Banner on unsupported browsers; native app as the upgrade path |
| API key sits in the browser/UserDefaults — visible to the user, and to anyone on their machine | Free-tier keys only; Ollama for the no-key path; a backend proxy if this ever gets real users |
| Provider CORS policy could block browser calls at any time | Four interchangeable providers behind one code path (both web and native) |
| Native app is ad-hoc codesigned, not notarized — Gatekeeper will warn or block on any machine but the developer's | Documented as a v1 limitation; each user builds it themselves via `./build.sh`, or right-click-Open to bypass Gatekeeper; notarization/Developer ID is future work if distributed beyond one machine |
| macOS on-device speech recognition quality/availability varies by language and OS version | Fall back to server-based recognition when on-device isn't supported (same Speech framework API); document macOS 14+ requirement |
| Recording a lecture may violate a course or campus policy | User's call; no audio is stored by either app |
