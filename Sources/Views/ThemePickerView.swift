import SwiftUI

struct ThemePickerView: View {
    @Binding var selection: AppTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(AppTheme.allCases) { theme in
                    swatch(theme)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func swatch(_ theme: AppTheme) -> some View {
        Button {
            HapticManager.tap()
            withAnimation(.snappy) { selection = theme }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(theme.backgroundGradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(theme.accent, lineWidth: selection == theme ? 3 : 0)
                    )
                    .overlay(
                        Group {
                            if selection == theme {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                        }
                    )
                    .scaleEffect(selection == theme ? 1.08 : 1.0)

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(selection == theme ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
    }
}
