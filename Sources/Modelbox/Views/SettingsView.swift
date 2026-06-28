import SwiftUI
import ServiceManagement
import AppKit
import Sparkle

struct SettingsView: View {
    @Environment(\.sparkleUpdater) private var sparkleUpdater

    @AppStorage("scanOllama") private var scanOllama: Bool = true
    @AppStorage("scanHuggingFace") private var scanHuggingFace: Bool = true
    @AppStorage("scanLMStudio") private var scanLMStudio: Bool = true
    @AppStorage("scanOpenWhispr") private var scanOpenWhispr: Bool = true
    @AppStorage("scanAppSupport") private var scanAppSupport: Bool = true
    @AppStorage("customScanPaths") private var customScanPaths: String = ""
    @AppStorage("huggingFaceToken") private var huggingFaceToken: String = ""
    @AppStorage("ramEstimateFactor") private var ramEstimateFactor: Double = 1.2
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            updatesSection

            Section {
                Toggle("Ollama", isOn: $scanOllama)
                Toggle("Hugging Face cache", isOn: $scanHuggingFace)
                Toggle("LM Studio", isOn: $scanLMStudio)
                Toggle("OpenWhispr", isOn: $scanOpenWhispr)
                Toggle("Application Support model folders", isOn: $scanAppSupport)
                TextField("Additional paths (comma-separated)", text: $customScanPaths)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Scan locations")
            }

            Section {
                SecureField("Token (optional)", text: $huggingFaceToken)
                    .textFieldStyle(.roundedBorder)
                Text("A token raises the Hugging Face API rate limit used by the Explorer.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Hugging Face")
            }

            Section {
                HStack {
                    Text("RAM estimate factor")
                    Spacer()
                    Stepper(value: $ramEstimateFactor, in: 1.0...2.0, step: 0.05) {
                        Text(String(format: "%.2f×", ramEstimateFactor))
                            .monospacedDigit()
                    }
                }
                Text("Estimated RAM to load a model ≈ disk size × factor.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Estimates")
            }

            Section {
                Toggle("Launch Modelbox at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLaunchAtLogin(newValue)
                    }
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
        .task {
            syncLaunchAtLoginFromSystem()
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch-at-login change failed: \(error)")
        }
    }

    private func syncLaunchAtLoginFromSystem() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    @ViewBuilder
    private var updatesSection: some View {
        if let updater = sparkleUpdater {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentVersionLine)
                            .font(.system(size: 12, weight: .medium))
                        Text("Modelbox checks for updates daily. You can also check manually.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    CheckForUpdatesView(updater: updater)
                }

                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
            } header: {
                Text("Updates")
            }
        }
    }

    private var currentVersionLine: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Current version: \(short) (build \(build))"
    }
}
