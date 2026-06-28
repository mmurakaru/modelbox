import SwiftUI
import AppKit

enum AppTab: String, CaseIterable, Identifiable {
    case overview
    case explorer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .explorer: "Explorer"
        }
    }
}

struct PopoverView: View {
    @Environment(ModelStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    @AppStorage("activeTab") private var activeTabRaw: String = AppTab.overview.rawValue

    private var activeTab: AppTab {
        AppTab(rawValue: activeTabRaw) ?? .overview
    }

    var body: some View {
        VStack(spacing: 0) {
            tabSwitcher
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)

            Divider()

            Group {
                switch activeTab {
                case .overview: OverviewView()
                case .explorer: ExplorerView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .frame(width: 360, height: 520)
        .task {
            store.rescan()
        }
        .onKeyPress(.escape) {
            NSApp.deactivate()
            return .handled
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isSelected = activeTab == tab
        return Button(action: { activeTabRaw = tab.rawValue }) {
            Text(tab.label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 6))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: { showSettings() }) {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(",", modifiers: .command)

            Button(action: { store.rescan() }) {
                Image(systemName: "arrow.clockwise")
                Text("Refresh")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)

            Spacer()

            Text("\(store.filteredModels.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Modelbox")
            .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 11))
        .background(
            HStack {
                Button("") { activeTabRaw = AppTab.overview.rawValue }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { activeTabRaw = AppTab.explorer.rawValue }
                    .keyboardShortcut("2", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Settings window

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where isSettingsWindow(window) {
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        let id = window.identifier?.rawValue ?? ""
        return id.contains("Settings") || id.contains("settings") || window.title == "Settings"
    }
}
