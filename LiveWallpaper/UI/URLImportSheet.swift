import SwiftUI

struct URLImportSheet: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import from URL")
                    .font(.title3.weight(.semibold))
                Text("Paste a direct link to a video file (MP4, MOV, M4V, GIF, WebM, or MKV).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("https://example.com/wallpaper.mp4", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .disabled(isLoading)
                .onSubmit(startImport)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Downloading…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isLoading)

                Button("Import", action: startImport)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || trimmedURL == nil)
            }
        }
        .padding(22)
        .frame(width: 440)
        .onAppear {
            isFocused = true
            if let clip = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let url = URL(string: clip), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                text = clip
            }
        }
    }

    private var trimmedURL: URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private func startImport() {
        guard let url = trimmedURL, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await store.importRemoteVideo(from: url)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
