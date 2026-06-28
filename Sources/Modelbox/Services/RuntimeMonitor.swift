import Foundation

/// How a resident model can be cleanly stopped.
enum StopTarget: Sendable, Equatable {
    case ollama(model: String)
    case process(pid: Int32, name: String)
}

/// Runtime state of a resident ("warm") model. Presence means warm; `stopTarget`
/// is non-nil only when it can be stopped cleanly (no quitting in-process host apps).
struct RuntimeInfo: Sendable, Equatable {
    var stopTarget: StopTarget?
}

/// Pure decision: given what's observed, is a model warm and cleanly stoppable?
enum RuntimeDecision {
    static func evaluate(
        source: ModelSource,
        modelName: String,
        ollamaLoaded: Set<String>,
        holder: (pid: Int32, name: String)?
    ) -> RuntimeInfo? {
        if source == .ollama {
            return ollamaLoaded.contains(modelName) ? RuntimeInfo(stopTarget: .ollama(model: modelName)) : nil
        }
        guard let holder else { return nil }
        // A dedicated llama-server process maps 1:1 to a model and can be terminated;
        // in-process app loaders cannot be stopped without quitting the whole app.
        let stoppable = holder.name == "llama-server"
        return RuntimeInfo(stopTarget: stoppable ? .process(pid: holder.pid, name: holder.name) : nil)
    }
}

/// Observes which models are resident in memory and stops the cleanly-stoppable ones.
actor RuntimeMonitor {
    private struct OllamaPS: Decodable {
        struct Entry: Decodable { let name: String }
        let models: [Entry]
    }

    func snapshot(for models: [LocalModel]) async -> [String: RuntimeInfo] {
        let ollamaLoaded = await ollamaLoadedNames()
        var result: [String: RuntimeInfo] = [:]
        for model in models {
            let holder = model.source == .ollama ? nil : fileHolder(model.path)
            if let info = RuntimeDecision.evaluate(
                source: model.source, modelName: model.name,
                ollamaLoaded: ollamaLoaded, holder: holder
            ) {
                result[model.id] = info
            }
        }
        return result
    }

    func stop(_ target: StopTarget) {
        switch target {
        case .ollama(let model):
            _ = Self.runTool("/usr/bin/env", ["ollama", "stop", model])
        case .process(let pid, _):
            kill(pid, SIGTERM)
        }
    }

    private func ollamaLoadedNames() async -> Set<String> {
        guard let url = URL(string: "http://localhost:11434/api/ps") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(OllamaPS.self, from: data) else { return [] }
        return Set(decoded.models.map(\.name))
    }

    /// First process holding the file open (memory-mapped = loaded), with its short command name.
    private func fileHolder(_ url: URL) -> (pid: Int32, name: String)? {
        guard let output = Self.runTool("/usr/sbin/lsof", ["-t", "--", url.path]),
              let firstLine = output.split(separator: "\n").first,
              let pid = Int32(firstLine.trimmingCharacters(in: .whitespaces)) else { return nil }
        let command = Self.runTool("/bin/ps", ["-o", "comm=", "-p", "\(pid)"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = command.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "process"
        return (pid, name)
    }

    private static func runTool(_ launchPath: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
