import SwiftUI

struct ContentView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(QueueViewModel.self) private var queue

    @State private var showSettings = false
    @State private var pendingProbe: ProbedMedia?

    var body: some View {
        NavigationStack {
            ZStack {
                settings.theme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    LinkInputView { url in
                        Task { await handleNewLink(url) }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if queue.items.isEmpty {
                        EmptyQueueState()
                            .frame(maxHeight: .infinity)
                    } else {
                        QueueListView()
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $pendingProbe) { probed in
                FormatPickerSheet(probed: probed) { format in
                    queue.enqueue(link: probed.link, format: format)
                    pendingProbe = nil
                }
                .presentationDetents([.fraction(0.55), .large])
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) {
                ToastHost()
            }
            .onAppear { queue.queueModeEnabled = settings.queueModeEnabled }
            .onChange(of: settings.queueModeEnabled) { _, newValue in
                queue.queueModeEnabled = newValue
            }
        }
    }

    private func handleNewLink(_ raw: String) async {
        guard let link = MediaLink(rawURL: raw) else {
            ToastCenter.shared.show("That doesn't look like a supported link", style: .error)
            return
        }

        if settings.skipPreferencePrompt {
            queue.enqueue(link: link, format: .bestAvailable)
            return
        }

        do {
            let probed = try await queue.probeFormats(for: link)
            pendingProbe = probed
        } catch {
            ToastCenter.shared.show("Couldn't read that link: \(error.localizedDescription)", style: .error)
        }
    }
}

private struct EmptyQueueState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.secondary)
            Text("Paste a link to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
