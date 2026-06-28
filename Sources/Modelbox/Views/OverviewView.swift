import SwiftUI
import AppKit

struct OverviewView: View {
    @Environment(ModelStore.self) private var store
    @AppStorage("ramEstimateFactor") private var ramEstimateFactor: Double = 1.2

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
                HStack(spacing: 6) {
                    Text("\(store.totalBytes.formattedBytes) on disk")
                    if store.reclaimableBytes > 0 {
                        Text("· \(store.reclaimableBytes.formattedBytes) reclaimable")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !store.models.isEmpty {
                Button(action: { store.findDuplicates() }) {
                    if store.isDetectingDuplicates {
                        ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 12, height: 12)
                    } else {
                        Label("Find duplicates", systemImage: "doc.on.doc")
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
                .disabled(store.isDetectingDuplicates)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.filteredModels) { model in
                    ModelRowView(
                        model: model,
                        ramFactor: ramEstimateFactor,
                        copies: store.copyCount(for: model),
                        onReveal: { reveal(model) },
                        onDelete: { performDelete(model) }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    private func reveal(_ model: LocalModel) {
        NSWorkspace.shared.activateFileViewerSelecting([model.path])
    }

    private func performDelete(_ model: LocalModel) {
        do {
            try FileManager.default.trashItem(at: model.path, resultingItemURL: nil)
            store.remove(model)
        } catch {
            NSSound.beep()
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
    let ramFactor: Double
    var copies: Int = 1
    var onReveal: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var isHovering = false
    @State private var confirmingDelete = false

    private var estimatedRAM: Int64 {
        RAMEstimate.bytes(forModelSize: model.sizeBytes, factor: ramFactor)
    }

    private var fit: RAMFit {
        RAMFit.evaluate(estimatedRAM: estimatedRAM, machineRAM: HardwareInfo.physicalMemoryBytes)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(model.source.displayName)
                    Text("~\(estimatedRAM.formattedBytes) RAM")
                    if copies > 1 {
                        Text("\(copies) copies")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer()
            if isHovering {
                actions
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.sizeBytes.formattedBytes)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                fitBadge
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .confirmationDialog(
            "Move \(model.name) to the Trash?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(model.sizeBytes.formattedBytes) at \(model.path.path)")
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")

            if ModelDeletion.canTrash(model) {
                Button(action: { confirmingDelete = true }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Move to Trash")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private var fitBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: fit.systemImage)
            Text(fit.label)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(fit.tint)
        .help("Estimated \(estimatedRAM.formattedBytes) vs \(HardwareInfo.physicalMemoryBytes.formattedBytes) of RAM")
    }
}
