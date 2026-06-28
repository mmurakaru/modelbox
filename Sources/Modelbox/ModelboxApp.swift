import SwiftUI
import Sparkle

@main
struct ModelboxApp: App {
    @State private var modelStore = ModelStore()

    private let updaterController: SPUStandardUpdaterController

    init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(modelStore)
                .environment(\.sparkleUpdater, updaterController.updater)
        } label: {
            Image(nsImage: MenuBarIcon.nsImage)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(modelStore)
                .environment(\.sparkleUpdater, updaterController.updater)
        }
    }
}

private struct SparkleUpdaterKey: EnvironmentKey {
    static let defaultValue: SPUUpdater? = nil
}

extension EnvironmentValues {
    var sparkleUpdater: SPUUpdater? {
        get { self[SparkleUpdaterKey.self] }
        set { self[SparkleUpdaterKey.self] = newValue }
    }
}
