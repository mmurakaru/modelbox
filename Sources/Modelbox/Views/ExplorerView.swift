import SwiftUI

struct ExplorerView: View {
    @AppStorage("huggingFaceToken") private var token: String = ""
    @State private var model = ExplorerModel()
    @FocusState private var searchFocused: Bool

    private var tokenOrNil: String? { token.isEmpty ? nil : token }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)

            filterBar
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            statusBar
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .task {
            if model.results.isEmpty {
                await model.search(token: tokenOrNil)
            }
        }
    }

    private var searchBar: some View {
        @Bindable var model = model
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search Hugging Face", text: $model.query.search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { runSearch() }
            if !model.query.search.isEmpty {
                Button(action: { model.query.search = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 6))
    }

    private var filterBar: some View {
        @Bindable var model = model
        return HStack(spacing: 6) {
            TextField("Lab", text: $model.query.author)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onSubmit { runSearch() }

            Picker("", selection: $model.query.library) {
                Text("Any format").tag(String?.none)
                Text("GGUF").tag(String?("gguf"))
                Text("MLX").tag(String?("mlx"))
            }
            .labelsHidden()
            .onChange(of: model.query.library) { runSearch() }

            Picker("", selection: $model.sizeBucket) {
                ForEach(SizeBucket.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()

            Picker("", selection: $model.query.sort) {
                ForEach(HFSort.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .onChange(of: model.query.sort) { runSearch() }
        }
        .font(.system(size: 10))
        .controlSize(.small)
    }

    private func runSearch() {
        Task { await model.search(token: tokenOrNil) }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.results.isEmpty {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.displayedResults.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.displayedResults) { hfModel in
                        HFModelRowView(model: hfModel)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(model.errorMessage ?? "No models found")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            if let message = model.errorMessage, !model.results.isEmpty {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.secondary)
                Text(message)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(lastSyncedLabel)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }
        }
        .font(.system(size: 10))
    }

    private var lastSyncedLabel: String {
        guard let synced = model.lastSynced else { return "Not synced yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last synced \(formatter.localizedString(for: synced, relativeTo: Date()))"
    }
}

struct HFModelRowView: View {
    let model: HFModel

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(model.lab)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let params = model.parameterHint {
                    Text(params)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let downloads = model.downloads {
                    Text("\(downloads.formattedCompact) ↓")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

private extension Int {
    var formattedCompact: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        switch self {
        case 1_000_000...:
            return (formatter.string(from: NSNumber(value: Double(self) / 1_000_000)) ?? "\(self)") + "M"
        case 1_000...:
            return (formatter.string(from: NSNumber(value: Double(self) / 1_000)) ?? "\(self)") + "k"
        default:
            return "\(self)"
        }
    }
}
