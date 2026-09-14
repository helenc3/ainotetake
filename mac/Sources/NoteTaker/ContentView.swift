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

    private var provider: Provider {
        Provider(rawValue: providerRaw) ?? .groq
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbarRow
            providerRow
            transcriptSection
            notesSection
        }
        .padding()
        .frame(minWidth: 700, minHeight: 560)
        .onAppear {
            transcriber.transcript = savedTranscript
            notes = savedNotes
            loadKey()
        }
        .onChange(of: transcriber.transcript) { _, newValue in
            savedTranscript = newValue
        }
        .onChange(of: providerRaw) { _, _ in
            loadKey()
        }
        .confirmationDialog("Clear transcript and notes?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                transcriber.clear()
                notes = ""
                savedTranscript = ""
                savedNotes = ""
                errorMessage = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var toolbarRow: some View {
        HStack {
            Button {
                transcriber.toggle()
            } label: {
                Label(transcriber.isRecording ? "Stop" : "Record",
                      systemImage: transcriber.isRecording ? "stop.fill" : "record.circle")
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)

            Button("Generate notes") {
                generateNotes()
            }
            .disabled(transcriber.transcript.isEmpty || isGenerating)

            Button("Copy") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(notes, forType: .string)
            }
            .disabled(notes.isEmpty)

            Spacer()

            Button("Clear") {
                showClearConfirm = true
            }
        }
    }

    private var providerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Picker("Provider", selection: $providerRaw) {
                    ForEach(Provider.allCases) { p in
                        Text(p.label).tag(p.rawValue)
                    }
                }
                .frame(maxWidth: 240)

                if provider.needsKey {
                    SecureField("API key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "key_" + provider.rawValue)
                        }
                }
            }
            Text(provider.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Transcript").font(.headline)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(transcriber.transcript + transcriber.partial)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("transcriptEnd")
                }
                .frame(height: 200)
                .background(Color.gray.opacity(0.08))
                .onChange(of: transcriber.transcript) { _, _ in
                    proxy.scrollTo("transcriptEnd", anchor: .bottom)
                }
                .onChange(of: transcriber.partial) { _, _ in
                    proxy.scrollTo("transcriptEnd", anchor: .bottom)
                }
            }
            if let err = transcriber.errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes").font(.headline)
            if isGenerating {
                ProgressView()
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(notes.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                        renderedLine(String(line))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func renderedLine(_ line: String) -> some View {
        let attributed = (try? AttributedString(
            markdown: line,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(line)

        if line.hasPrefix("### ") {
            Text(attributed).font(.subheadline).bold()
        } else if line.hasPrefix("## ") {
            Text(attributed).font(.title3).bold()
        } else if line.hasPrefix("# ") {
            Text(attributed).font(.title2).bold()
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            Text("•  \(attributed)")
        } else {
            Text(attributed)
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
