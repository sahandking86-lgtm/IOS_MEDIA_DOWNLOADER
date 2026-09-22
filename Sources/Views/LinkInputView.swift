import SwiftUI

struct LinkInputView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var text = ""
    @FocusState private var focused: Bool
    var onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField("Paste a video link", text: $text)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .onSubmit(submit)

            if !text.isEmpty {
                Button {
                    withAnimation(.snappy) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Button(action: submit) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(settings.theme.cardMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .animation(.snappy, value: text.isEmpty)
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        HapticManager.tap()
        onSubmit(value)
        text = ""
        focused = false
    }
}
