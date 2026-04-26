import SwiftUI

struct StarButton: View {
    @EnvironmentObject private var stars: StarStore
    let id: UUID

    var body: some View {
        Button {
            stars.toggle(id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: stars.isStarred(id) ? "star.fill" : "star")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(stars.isStarred(id) ? Color.yellow : Color.gray.opacity(0.6))
                .padding(10)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
