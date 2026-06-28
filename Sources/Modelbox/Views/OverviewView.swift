import SwiftUI

struct OverviewView: View {
    @Environment(ModelStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.models.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.models.count) model\(store.models.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(store.totalBytes.formattedBytes) on disk")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.filteredModels) { model in
                    ModelRowView(model: model)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No local models detected")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Modelbox scans Ollama, the Hugging Face cache, and app model folders for downloaded weights.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

struct ModelRowView: View {
    let model: LocalModel

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(model.source.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.sizeBytes.formattedBytes)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
