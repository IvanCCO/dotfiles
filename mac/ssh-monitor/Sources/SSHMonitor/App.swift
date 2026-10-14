import SwiftUI
import AppKit

@main struct SSHMonitorApp: App {
    @StateObject private var monitor = Monitor()
    var body: some Scene {
        MenuBarExtra {
            MonitorPanel(monitor: monitor)
        } label: {
            Image(nsImage: statusIcon).accessibilityLabel("SSH Monitor")
        }.menuBarExtraStyle(.window)
    }

    private var statusIcon: NSImage {
        let image = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "SSH Monitor")!
        switch monitor.snapshot?.memoryAlert ?? .normal {
        case .normal:
            image.isTemplate = true
            return image
        case .high, .swap:
            let color: NSColor = monitor.snapshot?.memoryAlert == .swap ? .systemRed : .systemYellow
            let colored = image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color])) ?? image
            colored.isTemplate = false
            return colored
        }
    }
}

struct NativeGlassBackground: NSViewRepresentable {
    let solid: Bool
    func makeNSView(context: Context) -> NSView { SSHMonitorGlassBackground(solid) }
    func updateNSView(_ view: NSView, context: Context) {}
}

struct MonitorPanel: View {
    @ObservedObject var monitor: Monitor
    @State private var sortByMemory = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    private var strongSecondary: Color { Color(nsColor: .labelColor).opacity(0.72) }
    private var surface: Color {
        scheme == .dark ? Color(white: 0.12) : Color(white: 0.98)
    }
    private var machineName: String { monitor.snapshot?.hostname ?? (monitor.selected.isEmpty ? "Máquina" : monitor.selected) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            Divider()
            if let data = monitor.snapshot {
                VStack(spacing: 6) {
                    metric("CPU", value: data.cpu, detail: "\(data.cores) núcleos", color: .blue)
                    metric("GPU", value: data.gpu?.utilization, detail: data.gpu.map { "\(Int($0.temperature)) °C" } ?? "Indisponível", color: .green)
                    metric("MEM", value: data.memoryUsed / data.memoryTotal * 100,
                           detail: String(format: "%.1f / %.1f GiB", data.memoryUsed, data.memoryTotal), color: .orange)
                    metric("SWAP", value: data.swapTotal > 0 ? data.swapUsed / data.swapTotal * 100 : nil,
                           detail: String(format: "%.2f / %.0f GiB", data.swapUsed, data.swapTotal), color: data.swapUsed > 0 ? .red : .purple)
                    if data.zramTotal > 0 {
                        Text(String(format: "Zram: %.1f / %.0f GiB · Swap: NVMe/disco", data.zramUsed, data.zramTotal))
                            .font(.system(size: 10)).foregroundStyle(strongSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let gpu = data.gpu {
                    HStack {
                        Text(gpu.name).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(Int(gpu.used)) / \(Int(gpu.total)) MB").monospacedDigit()
                    }.font(.system(size: 10)).foregroundStyle(strongSecondary)
                } else {
                    Label("Monitoramento da GPU indisponível", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(strongSecondary)
                        .help("Não foi possível ler a GPU pelo nvidia-smi ou pela biblioteca NVIDIA NVML.")
                }
                Divider()
                processList(data)
            } else {
                connectionPlaceholder
            }
            Divider()
            footer
        }
        .padding(14).frame(width: 350)
        .foregroundStyle(.primary)
        .background(NativeGlassBackground(solid: reduceTransparency || contrast == .increased)
            .id(reduceTransparency || contrast == .increased))
        .controlSize(.small)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                if monitor.hosts.count > 1 {
                    Menu {
                        ForEach(monitor.hosts, id: \.self) { host in
                            Button { monitor.selected = host; monitor.connect() } label: {
                                if monitor.selected == host { Label(host, systemImage: "checkmark") } else { Text(host) }
                            }
                        }
                    } label: { Text(machineName).font(.system(size: 17, weight: .semibold)) }
                    .menuStyle(.borderlessButton).fixedSize()
                } else {
                    Text(machineName).font(.system(size: 17, weight: .semibold))
                }
                if let data = monitor.snapshot {
                    Text("\(data.user) · \(data.system)")
                        .font(.system(size: 11)).foregroundStyle(strongSecondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(monitor.selected).font(.caption).foregroundStyle(strongSecondary)
                }
            }
            Spacer(minLength: 8)
            Toggle("Conexão SSH", isOn: Binding(get: {
                monitor.connected || monitor.status == "Conectando…"
            }, set: { enabled in
                enabled ? monitor.connect() : monitor.disconnect()
            })).toggleStyle(.switch).labelsHidden().help("Conectar ou desconectar")
        }
    }

    private func metric(_ title: String, value: Double?, detail: String, color: Color) -> some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(surface.opacity(contrast == .increased ? 1 : 0.90))
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(scheme == .dark ? 0.38 : 0.24))
                        .frame(width: geometry.size.width * min(1, max(0, (value ?? 0) / 100)))
                }
            }
            HStack(spacing: 7) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 3, height: 13)
                    Text(title).font(.system(size: 11, weight: .bold))
                }.frame(width: 47, alignment: .leading)
                Text(value.map { String(format: "%.0f%%", $0) } ?? "—")
                    .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                Spacer(minLength: 4)
                Text(detail).font(.system(size: 10)).monospacedDigit()
            }.padding(.horizontal, 9)
        }.frame(height: 32).clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(detail)")
    }

    private func processList(_ data: Snapshot) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Processos ativos").font(.system(size: 12, weight: .semibold))
                Spacer()
                Picker("Ordenar por", selection: $sortByMemory) {
                    Text("CPU").tag(false)
                    Text("MEM").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 100)
            }
            HStack {
                Text("Processo / usuário")
                Spacer()
                Text("CPU").frame(width: 48, alignment: .trailing)
                Text("MEM").frame(width: 56, alignment: .trailing)
            }.font(.system(size: 10)).foregroundStyle(strongSecondary)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(data.processes.sorted { sortByMemory ? $0.memory > $1.memory : $0.cpu > $1.cpu }.prefix(20)) { process in
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(process.name).font(.system(size: 11, weight: .medium)).lineLimit(1).help(process.name)
                                Text("\(process.user) · PID \(String(process.pid))")
                                    .font(.system(size: 10)).foregroundStyle(strongSecondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(String(format: "%.1f%%", process.cpu)).frame(width: 48, alignment: .trailing)
                            Text(String(format: "%.0f MB", process.memory)).foregroundStyle(strongSecondary).frame(width: 56, alignment: .trailing)
                        }.font(.system(size: 10)).monospacedDigit().padding(.vertical, 5)
                        Divider()
                    }
                }
            }.frame(height: 150)
            Text("A cada 2 s · CPU dos processos: 100% = 1 núcleo")
                .font(.system(size: 10)).foregroundStyle(strongSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding(10)
            .background(surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 10))
    }

    private var connectionPlaceholder: some View {
        VStack(spacing: 6) {
            if monitor.status == "Conectando…" { ProgressView().controlSize(.small) }
            Text(monitor.status).font(.headline)
            Text(monitor.error.isEmpty ? (monitor.hosts.isEmpty ? "Adicione um Host em ~/.ssh/config e recarregue a lista." : "Aguardando os recursos da máquina…") : monitor.error)
                .font(.caption).foregroundStyle(strongSecondary).multilineTextAlignment(.center).textSelection(.enabled)
            Button("Reconectar") { monitor.connect() }
        }.frame(maxWidth: .infinity, minHeight: 180).padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(monitor.connected ? Color.green : monitor.status == "Conectando…" ? Color.orange : Color.gray).frame(width: 6, height: 6)
            Text(monitor.status).font(.system(size: 10))
            Spacer()
            Text(machineName).font(.system(size: 10)).foregroundStyle(strongSecondary).lineLimit(1)
            Menu {
                Button("Reconectar") { monitor.connect() }
                Button("Recarregar máquinas") { monitor.reloadHosts() }
                Divider()
                Button("Reiniciar app") { restart() }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().help("Opções")
        }
    }

    private func restart() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try task.run()
            monitor.disconnect()
            NSApplication.shared.terminate(nil)
        } catch {
            monitor.error = error.localizedDescription
        }
    }
}
