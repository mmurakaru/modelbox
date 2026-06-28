import SwiftUI

struct ExplorerView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Discover models")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Browse models available to download, filtered by lab and size.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
