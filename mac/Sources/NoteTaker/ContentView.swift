import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var transcriber = Transcriber()

    @AppStorage("provider") private var providerRaw: String = Provider.groq.rawValue
    @AppStorage("savedTranscript") private var savedTranscript: String = ""
    @AppStorage("savedNotes") private var savedNotes: String = ""

    @State private var apiKey: String = ""
    @State private var notes: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showClearConfirm = false
    @State private var startedAt: Date?

    private var provider: Provider {
        Provider(rawValue: providerRaw) ?? .groq
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    modelSection
                    transcriptSection
                    notesSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 720, minHeight: 580)
        .onAppear {
            transcriber.transcript = savedTranscript
            notes = savedNotes
            loadKey()
        }
        .onChange(of: transcriber.transcript) { _, newValue in savedTranscript = newValue }
        .onChange(of: providerRaw) { _, _ in loadKey() }
        .onChange(of: transcriber.isRecording) { _, recording in
            startedAt = recording ? Date() : nil
        }
        .confirmationDialog("Delete this transcript and its notes?", isPresented: $showClearConfirm) {
            Button("Delete", role: .destructive) {
                transcriber.clear()
                notes = ""
                savedTranscript = ""
                savedNotes = ""
                errorMessage = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(spacing: 12) {
            Text("Lecture Notes")
                .font(.system(size: 15, weight: .semibold))

            if transcriber.isRecording { liveIndicator }

            Spacer(minLength: 16)

            Button {
                transcriber.toggle()
            } label: {
                Label(transcriber.isRecording ? "Stop" : "Record",
                      systemImage: transcriber.isRecording ? "stop.fill" : "record.circle")
                    .frame(minWidth: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut("r", modifiers: .command)

            Button("Generate notes", action: generateNotes)
                .disabled(transcriber.transcript.isEmpty || isGenerating)
                .keyboardShortcut(.return, modifiers: .command)

            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(notes, forType: .string)
            }
            .disabled(notes.isEmpty)

            Button("Clear") { showClearConfirm = true }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(transcriber.transcript.isEmpty && notes.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var liveIndicator: some View {
        // Ticks once a second only while recording; no timer to tear down.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = Int(context.date.timeIntervalSince(startedAt ?? context.date))
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 7, height: 7)
                    .opacity(seconds.isMultiple(of: 2) ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.6), value: seconds)
                Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
                    .font(.system(size: 12).monospacedDigit())
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Sections

    private func sectionLabel(_ text: String, trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.9)
            if let trailing {
                Text(trailing).font(.system(size: 11))
            }
        }
        .foregroundStyle(.tertiary)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Model", trailing: "key stays on this Mac")
            HStack(spacing: 8) {
                Picker("", selection: $providerRaw) {
                    ForEach(Provider.allCases) { p in Text(p.label).tag(p.rawValue) }
                }
                .labelsHidden()
                .frame(width: 230)

                if provider.needsKey {
                    SecureField("API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                        .onChange(of: apiKey) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "key_" + provider.rawValue)
                        }
                }
                Spacer()
            }
            Text(provider.hint + " · " + provider.model)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Transcript", trailing: transcriber.isRecording ? "listening" : nil)

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if transcriber.transcript.isEmpty && transcriber.partial.isEmpty {
                            Text("Press Record and the lecture appears here as it is spoken.")
                                .italic()
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(transcriber.transcript)
                                .foregroundStyle(.secondary)
                            + Text(transcriber.partial)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .id("end")
                }
                .frame(height: 190)
                .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 1))
                .onChange(of: transcriber.transcript) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
                .onChange(of: transcriber.partial) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }

            if let err = transcriber.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Notes")

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Writing notes…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            } else if notes.isEmpty {
                Text("Record a lecture, then press Generate notes.")
                    .italic()
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            // Notes read as a document, not as chrome.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(notes.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                    renderedLine(String(line))
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    @ViewBuilder
    private func renderedLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indent = CGFloat(line.prefix(while: { $0 == " " }).count) * 8
        let attributed = (try? AttributedString(
            markdown: trimmed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(trimmed)

        if trimmed.isEmpty {
            Color.clear.frame(height: 6)
        } else if trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") {
            VStack(alignment: .leading, spacing: 6) {
                Text(attributed.strippingPrefix())
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                Divider()
            }
            .padding(.top, 18)
            .padding(.bottom, 6)
        } else if trimmed.hasPrefix("### ") {
            Text(attributed.strippingPrefix())
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .padding(.top, 12)
                .padding(.bottom, 2)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.tertiary)
                Text(attributed.strippingPrefix())
                    .font(.system(size: 14, design: .serif))
                    .lineSpacing(3)
            }
            .padding(.leading, indent)
            .padding(.vertical, 2)
        } else {
            Text(attributed)
                .font(.system(size: 14, design: .serif))
                .lineSpacing(3)
                .padding(.vertical, 3)
        }
    }

    private func loadKey() {
        apiKey = UserDefaults.standard.string(forKey: "key_" + provider.rawValue) ?? ""
    }

    private func generateNotes() {
        errorMessage = nil
        isGenerating = true
        let transcript = transcriber.transcript
        let currentProvider = provider
        let key = apiKey
        Task {
            do {
                let result = try await NotesClient.generate(transcript: transcript, provider: currentProvider, key: key)
                notes = result
                savedNotes = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

private extension AttributedString {
    /// Drops the leading markdown marker ("## ", "- ", …) that AttributedString keeps as literal text.
    func strippingPrefix() -> AttributedString {
        let plain = String(self.characters)
        guard let range = plain.range(of: #"^([#]{1,3}|[-*])\s+"#, options: .regularExpression) else { return self }
        var copy = self
        let distance = plain.distance(from: plain.startIndex, to: range.upperBound)
        if let end = copy.index(copy.startIndex, offsetByCharacters: distance) as AttributedString.Index? {
            copy.removeSubrange(copy.startIndex..<end)
        }
        return copy
    }
}
