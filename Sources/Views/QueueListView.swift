import SwiftUI

struct QueueListView: View {
    @Environment(QueueViewModel.self) private var queue

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(queue.items) { item in
                    QueueRowView(item: item)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: queue.items.map(\.id))
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
