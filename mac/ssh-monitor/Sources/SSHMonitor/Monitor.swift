import Foundation
import Darwin

struct GPU: Decodable { let name: String; let utilization, used, total, temperature: Double }
struct RemoteProcess: Decodable, Identifiable {
    let pid: Int
    let name, user: String
    let cpu, memory: Double
    var id: Int { pid }
}
enum MemoryAlert { case normal, high, swap }

struct Snapshot: Decodable {
    let hostname, user, system: String
    let cpu: Double
    let cores: Int
    let memoryUsed, memoryTotal: Double
    let swapUsed, swapTotal, zramUsed, zramTotal: Double
    var memoryAlert: MemoryAlert {
        if swapUsed > 0 { return .swap }
        return memoryUsed > 12 ? .high : .normal
    }
    let gpu: GPU?
    let processes: [RemoteProcess]
}

enum SSHHosts {
    static func load() -> [String] {
        var visited = Set<String>()
        var hosts = Set<String>()
        func read(_ path: String) {
            let expanded = NSString(string: path).expandingTildeInPath
            guard visited.insert(expanded).inserted, let contents = try? String(contentsOfFile: expanded, encoding: .utf8) else { return }
            for line in contents.components(separatedBy: .newlines) {
                let tokens = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0].replacingOccurrences(of: "=", with: " ").split(whereSeparator: { $0.isWhitespace }).map(String.init)
                guard let key = tokens.first?.lowercased() else { continue }
                if key == "host" {
                    hosts.formUnion(tokens.dropFirst().filter { !$0.contains(where: { "*?!".contains($0) }) && !$0.hasPrefix("-") })
                } else if key == "include" {
                    for pattern in tokens.dropFirst() {
                        let full = pattern.hasPrefix("/") || pattern.hasPrefix("~") ? NSString(string: pattern).expandingTildeInPath : NSHomeDirectory() + "/.ssh/" + pattern
                        var matches = glob_t()
                        if glob(full, 0, nil, &matches) == 0, let paths = matches.gl_pathv {
                            for index in 0..<Int(matches.gl_pathc) { if let path = paths[index] { read(String(cString: path)) } }
                        }
                        globfree(&matches)
                    }
                }
            }
        }
        read(NSHomeDirectory() + "/.ssh/config")
        read("/etc/ssh/ssh_config")
        return hosts.sorted()
    }
}

@MainActor final class Monitor: ObservableObject {
    @Published var hosts = SSHHosts.load()
    @Published var selected = ""
    @Published var snapshot: Snapshot?
    @Published var status = "Desconectada"
    @Published var error = ""
    @Published var connected = false
    private var process: Process?
    private var generation = UUID()
    private var lastUpdate = Date.distantPast
    private var watchdog: Timer?

    init() {
        let saved = UserDefaults.standard.string(forKey: "host") ?? ""
        selected = hosts.contains(saved) ? saved : hosts.first ?? ""
        if !selected.isEmpty { connect() }
        watchdog = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.connected, Date().timeIntervalSince(self.lastUpdate) > 15 else { return }
                self.disconnect()
                self.status = "Sem resposta"
                self.error = "A máquina deixou de enviar dados. Clique em reconectar."
            }
        }
    }

    func disconnect() {
        generation = UUID()
        process?.terminate()
        process = nil
        connected = false
        snapshot = nil
        status = "Desconectada"
    }

    func connect() {
        disconnect()
        guard !selected.isEmpty, !selected.hasPrefix("-") else { return }
        UserDefaults.standard.set(selected, forKey: "host")
        status = "Conectando…"
        error = ""
        let token = generation
        let host = selected
        guard let url = Bundle.main.url(forResource: "collector", withExtension: "py"), let script = try? Data(contentsOf: url) else {
            status = "Erro"; error = "Coletor não encontrado."; return
        }
        let task = Process()
        let input = Pipe(), output = Pipe(), errors = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        task.arguments = ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2", host, "python3 -u -"]
        task.standardInput = input; task.standardOutput = output; task.standardError = errors
        do { try task.run() } catch {
            status = "Erro"; self.error = error.localizedDescription; return
        }
        process = task
        DispatchQueue.global(qos: .utility).async {
            input.fileHandleForWriting.write(script)
            try? input.fileHandleForWriting.close()
            var buffer = Data()
            while true {
                let chunk = output.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 10) {
                    let line = Data(buffer[..<newline])
                    buffer.removeSubrange(...newline)
                    guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: line) else { continue }
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        self.snapshot = snapshot; self.connected = true; self.status = "Conectada"; self.lastUpdate = Date()
                    }
                }
            }
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            task.waitUntilExit()
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.connected = false; self.snapshot = nil; self.status = "Desconectada"
                self.error = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Conexão encerrada. Clique em reconectar." : message.trimmingCharacters(in: .whitespacesAndNewlines)
                self.process = nil
            }
        }
    }

    func reloadHosts() { hosts = SSHHosts.load() }
}
