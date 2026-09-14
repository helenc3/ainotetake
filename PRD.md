# PRD — AI Lecture Note Taker

**Status:** v0 shipped · **Owner:** Helen · **Last updated:** 2026-09-14

## Problem

Students can either listen to a lecture or write it down, not both. Existing
tools (Otter, Notion AI) require an account, a subscription, and uploading
recordings of someone else's class to a third-party server.

## Users

Primary: a student in a live lecture with a laptop open.
Secondary: anyone in a long meeting who wants structured notes, not a transcript.

## Goals

1. Zero setup friction — open a URL, click record, get notes. No signup.
2. Notes are *structured* (summary, key points, terms, action items), not a wall of text.
3. Free to run. Free-tier API key, or fully local.

## Non-goals (v1)

- Accounts, sync, or a backend of any kind
- Storing or replaying audio
- Multi-speaker diarization, slides/PDF ingestion, real-time notes while recording
- Mobile app

## Requirements

| # | Requirement | Status |
|---|---|---|
| R1 | Capture live speech to text in the browser, hands-free, for a full lecture (60–90 min) | ✅ |
| R2 | Survive the browser's ~60s recognition timeout without losing transcript | ✅ auto-restart |
| R3 | Turn the raw transcript into structured markdown notes on demand | ✅ |
| R4 | Work with a free API key; user picks the provider | ✅ 4 providers |
| R5 | Option to run with no key and no data leaving the machine | ✅ Ollama |
| R6 | Copy notes out to any other app | ✅ |
| R9 | Transcript and notes survive an accidental reload | ✅ localStorage |
| R7 | Never transmit or persist the API key beyond the user's own browser | ✅ localStorage |
| R8 | Show a clear error when the mic is denied or the API rejects the call | ✅ |

## Success metrics

- A 60-minute lecture produces usable notes in one click, under 30s.
- Zero cost per user at the free tiers.
- Time-to-first-note for a new user: under 2 minutes including getting a key.

## Risks

| Risk | Mitigation |
|---|---|
| Web Speech API is Chrome/Edge/Safari only, quality varies by accent | Banner on unsupported browsers; Whisper-in-browser as the upgrade path |
| API key sits in the browser — visible to the user, and to anyone on their machine | Free-tier keys only; Ollama for the no-key path; a backend proxy if this ever gets real users |
| Provider CORS policy could block browser calls at any time | Four interchangeable providers behind one code path |
| Recording a lecture may violate a course or campus policy | User's call; no audio is stored anyway |
