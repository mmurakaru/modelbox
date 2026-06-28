import SwiftUI

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
                Text("\(store.totalBytes.formattedBytes) on disk")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Mac: \(HardwareInfo.physicalMemoryBytes.formattedBytes) RAM")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.filteredModels) { model in
                    ModelRowView(model: model, ramFactor: ramEstimateFactor)
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
    let ramFactor: Double

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
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer()
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
