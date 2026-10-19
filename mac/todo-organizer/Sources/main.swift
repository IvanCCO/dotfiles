import SwiftUI
import UniformTypeIdentifiers

private let organizerDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Todo Organizer", isDirectory: true)
private let dataURL = organizerDirectory.appendingPathComponent("todos.json")
private let orderURL = organizerDirectory.appendingPathComponent("organizer.json")
private let legacyDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.raycast.macos/extensions/4ae8dc37-8d8f-42fa-81ab-bf3afd603cbe")

struct Todo: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var completed: Bool
    var timeAdded: Int64
    var priority: Int?
    var tag: String?
    var parent: String?
}

struct TodoGroup: Identifiable, Hashable {
    var id: String
    var name: String
}

enum TodoListRow: Identifiable {
    case group(TodoGroup)
    case task(Todo, depth: Int)

    var id: String {
        switch self {
        case .group(let group): "group:\(group.id)"
        case .task(let task, _): "task:\(task.title)"
        }
    }
}

@MainActor final class TodoStore: ObservableObject {
    @Published var tasks: [Todo] = []
    @Published var collapsed = Set<String>()
    @Published var search = ""
    @Published var showingCompleted = false
    @Published var isCreatingGroup = false
    @Published var isCommandMenu = false
    @Published var groups: [TodoGroup] = []
    @Published var collapsedGroups = Set<String>()
    @Published var animatingCompletion = Set<String>()
    @Published var exitingCompletion = Set<String>()
    @Published private(set) var orderRevision = 0
    @Published var error: String?

    private var sortOrder: [String] = []
    private var groupOrder: [String] = []
    private var groupByTask: [String: String] = [:]
    private var rawRows: [String: [String: Any]] = [:]
    private var saving = false

    init() {
        prepareDataFile()
        reload()
    }

    private func prepareDataFile() {
        guard !FileManager.default.fileExists(atPath: dataURL.path) else { return }
        do {
            try FileManager.default.createDirectory(at: organizerDirectory, withIntermediateDirectories: true)
            let legacy = legacyDirectory.appendingPathComponent("todo.json")
            let backup = legacyDirectory.appendingPathComponent("todo.json.backup")
            if FileManager.default.fileExists(atPath: legacy.path) {
                try FileManager.default.copyItem(at: legacy, to: dataURL)
            } else if FileManager.default.fileExists(atPath: backup.path) {
                try FileManager.default.copyItem(at: backup, to: dataURL)
            } else {
                let data = try JSONSerialization.data(withJSONObject: Self.recoveredTodos, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: dataURL, options: .atomic)
            }
        } catch let caught { self.error = "Não consegui restaurar sua lista: \(caught.localizedDescription)" }
    }

    private static let recoveredTodos: [String: Any] = {
        typealias Seed = (String, Bool, Int64, Int?, String?)
        let rows: [Seed] = [
            ("Adicionar na página do professor dados de monitoramento na lista", false, 1791848817095, 2, nil),
            ("Meu blog arrumar", false, 1791924826248, 2, nil),
            ("Estruturar atividade para só um aluno pelo painel do professor (depois que automatizar criação de lista do cronograma)", false, 1791941673507, 1, nil),
            ("Adicionar perfil de diretora maple bear para validarmos e passar os acessos", false, 1792017083347, 3, nil),
            ("Estruturar - Lista de revisão para prova", false, 1792093713695, 1, "Mais ou menos"),
            ("Backfill formato e bloom exercício já feitos maple bear", false, 1792096959519, 2, "Rápido"),
            ("[JEV] - Bloom x Formato x BNCC", false, 1792270658759, 3, nil),
            ("Mudar o design backoffice para ser mais fácil colocar Skin", false, 1792272269875, 3, nil),
            ("Colocar blur na skin bloqueada", false, 1792411944463, 3, nil),
            ("Criar skins backoffice", false, 1792417343728, nil, nil),
            ("Desbloquear Grokbot", false, 1792418171064, nil, nil),
            ("Fluxo de criação de lista no backoffice com melhoria do PNG", false, 1792419204421, nil, nil),
            ("Ler grokbot", false, 1792424595543, nil, nil),
            ("Monitorar respostas de exercícios iguais", false, 1792427932577, nil, nil),
            ("Arrumar arquivo de banner", false, 1792429585506, nil, nil),
            ("Estruturar estratégia de realases Brio", false, 1792430634985, nil, nil),
            ("Bug imagens skins", false, 1792430738593, nil, nil),
            ("Desmockar dados escola 2", false, 1792433264263, nil, nil),
            ("Fluxo de teste e2e automatizado", false, 1792433526325, nil, nil),
            ("Adicionar consumo no tmux", true, 1791849322524, nil, nil),
            ("Limpar macbook", true, 1791858032569, nil, nil),
            ("Transcript aula", true, 1791857559384, nil, nil),
            ("Animação no uso da DICA", true, 1791858716659, nil, nil),
            ("Adicionar gravidade + size (vouch:trusted - size:M)", true, 1791897806370, nil, nil),
            ("Blog com IA 5 posts por mês", true, 1791857932569, nil, nil),
            ("Sub-título blog", true, 1791857962946, nil, nil),
            ("Taskbar com status da máquina remota CPU - Memória etc...", true, 1791907154946, nil, nil),
            ("Adicionar atividade para aluno Gabriel", true, 1791941981736, nil, nil),
            ("Fazer relatório do C6 - Nubank - Revolut de gastos", true, 1791929017692, nil, nil),
            ("Adicionar no analytics feature announcement no professor", true, 1791949185892, nil, nil),
            ("Deixar mais devagar corrida do Brio na lista de exercícios", true, 1792001857195, nil, nil),
            ("Ter um ver mais nos formatos e bloom para post no blog", true, 1791928417085, nil, nil),
            ("Bug de pesquisa backoffice - Search", true, 1791985535042, nil, nil),
            ("Desmockar dados da análise", true, 1791848829114, nil, nil),
            ("Bugs página da análise professor Slack", true, 1792096925625, nil, nil),
            ("Conferir agents.md", true, 1792110897709, nil, nil),
            ("Bug de tempo de exercício", true, 1792003500710, nil, nil),
            ("Adicionar na home skins e pedido pan", true, 1791941986927, nil, nil),
            ("Call Priscila para entender o que ela faz", true, 1792088041534, nil, nil),
            ("Novidades Brio", true, 1792429170297, nil, nil),
            ("Não ter ranking vila aprendiz", true, 1792089256845, nil, nil),
            ("Ver pedidos pam para home com skin", true, 1792419159240, nil, nil),
            ("Perfil do usuário como Doulingo [ Slack ]", true, 1792121063934, nil, nil),
            ("Ao entrar na home vê o banner das skins", true, 1792429385671, nil, nil)
        ]
        let todos = rows.map { title, completed, timeAdded, priority, tag -> [String: Any] in
            var row: [String: Any] = ["title": title, "completed": completed, "timeAdded": timeAdded]
            if let priority { row["priority"] = priority }
            if let tag { row["tag"] = tag }
            return row
        }
        return ["pinned": [], "todo": todos.filter { !($0["completed"] as? Bool ?? false) },
                "completed": todos.filter { $0["completed"] as? Bool ?? false }]
    }()

    func reload() {
        do {
            let data = try Data(contentsOf: dataURL)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let metaData = (try? Data(contentsOf: orderURL)) ?? Data()
            let meta = (try? JSONSerialization.jsonObject(with: metaData)) as? [String: Any] ?? [:]
            let hasSavedOrder = meta["order"] != nil
            sortOrder = meta["order"] as? [String] ?? []
            let parents = meta["parents"] as? [String: String] ?? [:]
            groups = (meta["groups"] as? [[String: String]] ?? []).compactMap { row in
                guard let id = row["id"], let name = row["name"] else { return nil }
                return TodoGroup(id: id, name: name)
            }
            groupOrder = meta["groupOrder"] as? [String] ?? groups.map(\.id)
            groupByTask = meta["groupByTask"] as? [String: String] ?? [:]
            collapsedGroups = Set(meta["collapsedGroups"] as? [String] ?? [])
            let all = ((root["todo"] as? [[String: Any]]) ?? []) + ((root["completed"] as? [[String: Any]]) ?? [])
            rawRows = Dictionary(all.compactMap { row in
                guard let title = row["title"] as? String else { return nil }
                return (title, row)
            }, uniquingKeysWith: { _, latest in latest })
            tasks = all.compactMap { row in
                guard let title = row["title"] as? String else { return nil }
                return Todo(title: title, completed: row["completed"] as? Bool ?? false,
                            timeAdded: row["timeAdded"] as? Int64 ?? 0,
                            priority: row["priority"] as? Int, tag: row["tag"] as? String,
                            parent: parents[title])
            }
            let known = Set(tasks.map(\.title))
            sortOrder = sortOrder.filter { known.contains($0) }
            groupByTask = groupByTask.filter { entry in
                known.contains(entry.key) && groups.contains(where: { $0.id == entry.value })
            }
            let knownGroups = Set(groups.map(\.id))
            groupOrder = groupOrder.filter { knownGroups.contains($0) }
            groupOrder.append(contentsOf: groups.map(\.id).filter { !groupOrder.contains($0) })
            if hasSavedOrder {
                sortOrder.append(contentsOf: tasks.map(\.title).filter { !sortOrder.contains($0) })
            } else {
                sortOrder = tasks.enumerated().sorted { lhs, rhs in
                    let leftPriority = lhs.element.priority ?? 0
                    let rightPriority = rhs.element.priority ?? 0
                    return leftPriority == rightPriority ? lhs.offset < rhs.offset : leftPriority > rightPriority
                }.map { $0.element.title }
                saveMetadata()
            }
            // Upgrade older folder-style groups to ordinary parent tasks.
            if !groups.isEmpty {
                for group in groups {
                    let existingParent = tasks.first(where: { $0.title.localizedCaseInsensitiveCompare(group.name) == .orderedSame })?.title
                    let parentTitle = existingParent ?? group.name
                    if existingParent == nil {
                        tasks.append(Todo(title: group.name, completed: false,
                                          timeAdded: Int64(Date().timeIntervalSince1970 * 1000),
                                          priority: nil, tag: nil, parent: nil))
                        sortOrder.insert(group.name, at: 0)
                    }
                    for index in tasks.indices where groupByTask[tasks[index].title] == group.id && tasks[index].title != parentTitle {
                        if tasks[index].parent == nil { tasks[index].parent = parentTitle }
                    }
                }
                groups = []
                groupOrder = []
                groupByTask = [:]
                collapsedGroups = []
                persistTasks()
            }
            error = nil
        } catch { self.error = "Não consegui ler a lista: \(error.localizedDescription)" }
    }

    var visibleRows: [TodoListRow] {
        _ = orderRevision // Publish manual ordering changes so SwiftUI refreshes immediately.
        let query = isCreatingGroup ? "" : search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingGroupIDs = Set(groups.filter { $0.name.localizedCaseInsensitiveContains(query) && !query.isEmpty }.map(\.id))
        let base = tasks.filter { task in
            (task.completed == showingCompleted || animatingCompletion.contains(task.title)) &&
            (query.isEmpty || task.title.localizedCaseInsensitiveContains(query) ||
             (task.tag ?? "").localizedCaseInsensitiveContains(query) ||
             matchingGroupIDs.contains(groupByTask[task.title] ?? ""))
        }
        let visibleTitles = Set(base.map(\.title))
        func children(of parent: String?) -> [Todo] {
            base.filter { task in
                task.parent == parent || (parent == nil && task.parent.map { !visibleTitles.contains($0) } == true)
            }.sorted { orderIndex($0.title) < orderIndex($1.title) }
        }
        func flatten(_ parent: String?, depth: Int) -> [TodoListRow] {
            children(of: parent).flatMap { item -> [TodoListRow] in
                let row: [TodoListRow] = [.task(item, depth: depth)]
                guard !collapsed.contains(item.title) else { return row }
                return row + flatten(item.title, depth: depth + 1)
            }
        }
        let visibleGroups = groups.filter { group in
            query.isEmpty || matchingGroupIDs.contains(group.id) || base.contains { groupByTask[$0.title] == group.id }
        }.sorted { groupIndex($0.id) < groupIndex($1.id) }
        var rows: [TodoListRow] = []
        for group in visibleGroups {
            rows.append(.group(group))
            guard !collapsedGroups.contains(group.id) else { continue }
            let groupedRoots = children(of: nil).filter { groupByTask[$0.title] == group.id }
            for task in groupedRoots {
                rows.append(.task(task, depth: 1))
                if !collapsed.contains(task.title) { rows.append(contentsOf: flatten(task.title, depth: 2)) }
            }
        }
        for task in children(of: nil) where groupByTask[task.title] == nil {
            rows.append(.task(task, depth: 0))
            if !collapsed.contains(task.title) { rows.append(contentsOf: flatten(task.title, depth: 1)) }
        }
        return rows
    }

    var canCreateSearch: Bool {
        let value = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        if isCreatingGroup { return !tasks.contains { $0.title.localizedCaseInsensitiveCompare(value) == .orderedSame } }
        return !tasks.contains { $0.title.localizedCaseInsensitiveCompare(value) == .orderedSame }
    }

    func depth(for task: Todo) -> Int {
        var depth = 0, cursor = task.parent, seen = Set<String>()
        while let title = cursor, !seen.contains(title) {
            seen.insert(title); depth += 1
            cursor = tasks.first(where: { $0.title == title })?.parent
        }
        return depth
    }

    func hasChildren(_ task: Todo) -> Bool { tasks.contains { $0.parent == task.title } }
    func orderIndex(_ title: String) -> Int { sortOrder.firstIndex(of: title) ?? Int.max }
    func groupIndex(_ id: String) -> Int { groupOrder.firstIndex(of: id) ?? Int.max }

    func tasks(in group: TodoGroup) -> [Todo] {
        tasks.filter { groupByTask[$0.title] == group.id && $0.parent == nil && $0.completed == showingCompleted }
    }

    func updateSearch(_ value: String) {
        if isCommandMenu && value.isEmpty {
            isCommandMenu = false
            search = ""
        } else if !isCommandMenu && !isCreatingGroup, let slash = value.firstIndex(of: "/") {
            isCommandMenu = true
            search = String(value[value.index(after: slash)...])
        } else {
            search = value
        }
    }

    func startGroupCreation() {
        isCommandMenu = false
        isCreatingGroup = true
        search = ""
    }

    func cancelCommandMode() {
        isCommandMenu = false
        isCreatingGroup = false
        search = ""
    }

    func addParentTask(_ title: String) { add(title) }

    func assign(_ task: Todo, to groupID: String?) {
        guard groups.contains(where: { $0.id == groupID }) || groupID == nil,
              let index = tasks.firstIndex(where: { $0.title == task.title }) else { return }
        tasks[index].parent = nil
        if let groupID { groupByTask[task.title] = groupID } else { groupByTask.removeValue(forKey: task.title) }
        saveMetadata()
    }

    func cycleGroup(for task: Todo) {
        let options: [String?] = [nil] + groupOrder.map(Optional.some)
        let current = groupByTask[task.title]
        let currentIndex = options.firstIndex(where: { $0 == current }) ?? 0
        assign(task, to: options[(currentIndex + 1) % options.count])
    }

    func toggleGroup(_ group: TodoGroup) {
        if collapsedGroups.contains(group.id) { collapsedGroups.remove(group.id) }
        else { collapsedGroups.insert(group.id) }
        saveMetadata()
    }

    func moveGroup(_ group: TodoGroup, by delta: Int) {
        guard let index = groupOrder.firstIndex(of: group.id) else { return }
        let destination = max(0, min(groupOrder.count - 1, index + delta))
        guard destination != index else { return }
        groupOrder.remove(at: index)
        groupOrder.insert(group.id, at: destination)
        orderRevision += 1
        saveMetadata()
    }

    func moveGroup(_ source: TodoGroup, before target: TodoGroup, position: CGFloat) {
        guard source.id != target.id,
              let targetIndex = groupOrder.firstIndex(of: target.id) else { return }
        groupOrder.removeAll { $0 == source.id }
        let adjustedTarget = groupOrder.firstIndex(of: target.id) ?? targetIndex
        let insertion = min(adjustedTarget + (position > 18 ? 1 : 0), groupOrder.count)
        groupOrder.insert(source.id, at: insertion)
        orderRevision += 1
        saveMetadata()
    }

    func moveTask(_ task: Todo, by delta: Int) {
        let siblings = tasks.filter { $0.parent == task.parent && groupByTask[$0.title] == groupByTask[task.title] }
            .sorted { orderIndex($0.title) < orderIndex($1.title) }
        guard let index = siblings.firstIndex(where: { $0.title == task.title }) else { return }
        let destination = max(0, min(siblings.count - 1, index + delta))
        guard destination != index else { return }
        sortOrder.removeAll { $0 == task.title }
        let target = siblings[destination].title
        let targetIndex = orderIndex(target)
        sortOrder.insert(task.title, at: min(targetIndex + (delta > 0 ? 1 : 0), sortOrder.count))
        orderRevision += 1
        saveMetadata()
    }

    func deleteGroup(_ group: TodoGroup) {
        groups.removeAll { $0.id == group.id }
        groupOrder.removeAll { $0 == group.id }
        groupByTask = groupByTask.filter { $0.value != group.id }
        collapsedGroups.remove(group.id)
        saveMetadata()
    }

    func add(_ title: String) {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !tasks.contains(where: { $0.title == value }) else { return }
        tasks.append(Todo(title: value, completed: false, timeAdded: Int64(Date().timeIntervalSince1970 * 1000), priority: nil, tag: nil, parent: nil))
        sortOrder.insert(value, at: 0); persistTasks()
    }

    func toggle(_ task: Todo) {
        guard let index = tasks.firstIndex(where: { $0.title == task.title }) else { return }
        let wasCompleted = tasks[index].completed
        guard !wasCompleted else {
            withAnimation(.easeOut(duration: 0.24)) { tasks[index].completed = false }
            persistTasks()
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            tasks[index].completed = true
            animatingCompletion.insert(task.title)
        }

        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let celebrationDuration: TimeInterval = reducedMotion ? 0.18 : 0.62
        DispatchQueue.main.asyncAfter(deadline: .now() + celebrationDuration) { [weak self] in
            guard let self else { return }
            if !reducedMotion {
                _ = withAnimation(.easeOut(duration: 0.28)) { self.exitingCompletion.insert(task.title) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reducedMotion ? 0.12 : 0.28)) { [weak self] in
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.24)) {
                    self.animatingCompletion.remove(task.title)
                    self.exitingCompletion.remove(task.title)
                }
                self.persistTasks()
            }
        }
    }

    func setParent(_ task: Todo, parent: String?) {
        guard task.title != parent,
              let index = tasks.firstIndex(where: { $0.title == task.title }) else { return }
        if let parent {
            var cursor: String? = parent
            while let title = cursor {
                if title == task.title { return }
                cursor = tasks.first(where: { $0.title == title })?.parent
            }
        }
        tasks[index].parent = parent
        if let parent, let groupID = groupByTask[parent] { groupByTask[task.title] = groupID }
        saveMetadata()
    }

    func drop(_ source: Todo, on target: Todo, position: CGFloat) {
        guard source.title != target.title else { return }
        guard let sourceIndex = tasks.firstIndex(where: { $0.title == source.title }) else { return }
        if position < 10 {
            tasks[sourceIndex].parent = target.parent
            if let groupID = groupByTask[target.title] { groupByTask[source.title] = groupID }
            sortOrder.removeAll { $0 == source.title }
            sortOrder.insert(source.title, at: orderIndex(target.title))
        } else if position > 31 {
            tasks[sourceIndex].parent = target.parent
            if let groupID = groupByTask[target.title] { groupByTask[source.title] = groupID }
            sortOrder.removeAll { $0 == source.title }
            let targetIndex = orderIndex(target.title)
            sortOrder.insert(source.title, at: min(targetIndex + 1, sortOrder.count))
        } else {
            setParent(source, parent: target.title)
            return
        }
        saveMetadata()
    }

    func delete(_ task: Todo) {
        let titles = Set([task.title] + descendants(of: task.title))
        tasks.removeAll { titles.contains($0.title) }
        sortOrder.removeAll { titles.contains($0) }
        groupByTask = groupByTask.filter { !titles.contains($0.key) }
        persistTasks()
    }

    private func descendants(of parent: String) -> [String] {
        let direct = tasks.filter { $0.parent == parent }.map(\.title)
        return direct + direct.flatMap(descendants)
    }

    private func persistTasks() {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            let data = try Data(contentsOf: dataURL)
            var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            func row(_ task: Todo) -> [String: Any] {
                var result = rawRows[task.title] ?? [:]
                result["title"] = task.title
                result["completed"] = task.completed
                result["timeAdded"] = task.timeAdded
                if let priority = task.priority { result["priority"] = priority }
                if let tag = task.tag { result["tag"] = tag }
                return result
            }
            root["todo"] = tasks.filter { !$0.completed }.map(row)
            root["completed"] = tasks.filter(\.completed).map(row)
            try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]).write(to: dataURL, options: .atomic)
            rawRows = Dictionary(tasks.map { ($0.title, row($0)) }, uniquingKeysWith: { _, latest in latest })
            saveMetadata()
            error = nil
        } catch { self.error = "Não consegui salvar a lista: \(error.localizedDescription)" }
    }

    private func saveMetadata() {
        let parents = Dictionary(tasks.compactMap { task in task.parent.map { (task.title, $0) } }, uniquingKeysWith: { _, last in last })
        do {
            let groupRows = groups.map { ["id": $0.id, "name": $0.name] }
            let metadata: [String: Any] = [
                "order": sortOrder,
                "parents": parents,
                "groups": groupRows,
                "groupOrder": groupOrder,
                "groupByTask": groupByTask,
                "collapsedGroups": Array(collapsedGroups)
            ]
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: orderURL, options: .atomic)
        } catch { self.error = "Não consegui salvar agrupamentos: \(error.localizedDescription)" }
    }
}

struct ContentView: View {
    @StateObject private var store = TodoStore()
    @State private var selectedRowID: String?
    @State private var commandSelection = 0
    @State private var showingKeymap = false
    @FocusState private var searchFocused: Bool
    @AppStorage("navigationKeymap") private var navigationKeymap = "control"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: store.isCreatingGroup ? "list.bullet.indent" : store.isCommandMenu ? "plus" : "magnifyingglass")
                    .font(.system(size: 15)).foregroundStyle(store.isCreatingGroup ? Color.accentColor : Color.secondary)
                TextField(store.isCreatingGroup ? "Nome da tarefa pai…" : store.isCommandMenu ? "Group ou Keymap…" : "Buscar ou adicionar tarefa…", text: Binding(
                    get: { store.search }, set: { store.updateSearch($0); commandSelection = 0 }
                ))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit(submitSearch)
                if store.canCreateSearch && !store.isCommandMenu {
                    Button(action: submitSearch) {
                        Image(systemName: store.isCreatingGroup ? "list.bullet.indent" : "plus.circle.fill")
                    }.buttonStyle(.plain).help(store.isCreatingGroup ? "Criar tarefa pai" : "Criar tarefa")
                }
                Divider().frame(height: 22)
                Button { store.showingCompleted = false } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(store.showingCompleted ? Color.secondary : Color.accentColor)
                }.buttonStyle(.plain).help("A fazer — ⌘1")
                Button { store.showingCompleted = true } label: {
                    Image(systemName: store.showingCompleted ? "eye.fill" : "eye")
                        .foregroundStyle(store.showingCompleted ? Color.accentColor : Color.secondary)
                }.buttonStyle(.plain).help("Concluídas — ⌘2")
            }
            .padding(.horizontal, 18).padding(.vertical, 14)

            Divider()

            ScrollViewReader { proxy in
                List {
                    if store.canCreateSearch && !store.isCommandMenu {
                        Button(action: submitSearch) {
                            Label("Criar \(store.isCreatingGroup ? "tarefa pai" : "tarefa") “\(store.search.trimmingCharacters(in: .whitespacesAndNewlines))”",
                                  systemImage: store.isCreatingGroup ? "list.bullet.indent" : "plus")
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                    }
                    ForEach(store.visibleRows) { row in
                        rowView(row)
                            .id(row.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(selectedRowID == row.id ? Color.accentColor.opacity(0.13) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRowID = row.id }
                            .dropDestination(for: String.self, action: { values, location -> Bool in
                                guard let payload = values.first else { return false }
                                return handleDrop(payload, on: row, at: location.y)
                            })
                            .contextMenu { contextMenu(for: row) }
                    }
                }
                .listStyle(.plain)
                .animation(.easeInOut(duration: 0.24), value: store.visibleRows.map(\.id))
                .background(KeyboardEventMonitor { handleKey($0, proxy: proxy) }.frame(width: 0, height: 0))
                .onAppear { searchFocused = true }
                .onChange(of: store.visibleRows.map(\.id)) { _, ids in
                    if let selectedRowID, !ids.contains(selectedRowID) { self.selectedRowID = nil }
                }
            }

            if let error = store.error {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red).padding(10)
            } else {
                HStack {
                    Text("\(store.visibleRows.count) itens")
                    Spacer()
                    Text("\(navigationLabel) J/K navegar · Enter recolher/concluir/criar · / comandos · ⌘1/2 listas")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 9)
            }
        }
        .frame(minWidth: 620, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .topLeading) {
            if store.isCommandMenu {
                GeometryReader { geometry in
                    commandPopover
                        .frame(width: 224)
                        .offset(x: min(max(14, cursorPositionX), geometry.size.width - 238), y: 54)
                        .zIndex(2)
                }
            }
        }
        .sheet(isPresented: $showingKeymap) { KeymapSettingsView() }
    }

    private var filteredCommands: [String] {
        ["Group", "Keymap"].filter { $0.localizedCaseInsensitiveContains(store.search) }
    }

    private var cursorPositionX: CGFloat {
        let width = (store.search as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        return 45 + width
    }

    private var commandPopover: some View {
        VStack(spacing: 2) {
            ForEach(Array(filteredCommands.enumerated()), id: \.element) { index, option in
                Button { chooseCommand(option) } label: {
                    HStack(spacing: 9) {
                        Image(systemName: option == "Group" ? "list.bullet.indent" : "keyboard")
                            .foregroundStyle(.secondary).frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option)
                            Text(option == "Group" ? "Criar tarefa pai" : "Configurar atalhos")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if index == commandSelection { Text("↵").font(.caption).foregroundStyle(.tertiary) }
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(index == commandSelection ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            if filteredCommands.isEmpty {
                Text("Nenhum comando encontrado").font(.caption).foregroundStyle(.secondary).padding(8)
            }
        }
        .padding(5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    private var navigationLabel: String {
        switch navigationKeymap {
        case "none": ""
        default: "Ctrl"
        }
    }

    private func chooseCommand(_ command: String) {
        switch command {
        case "Group": store.startGroupCreation()
        case "Keymap":
            store.cancelCommandMode()
            showingKeymap = true
        default: break
        }
    }

    @ViewBuilder private func rowView(_ row: TodoListRow) -> some View {
        switch row {
        case .group(let group):
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.tertiary)
                Button { store.toggleGroup(group) } label: {
                    Image(systemName: store.collapsedGroups.contains(group.id) ? "chevron.right" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
                Image(systemName: "folder.fill").foregroundStyle(.tint)
                Text(group.name).fontWeight(.semibold)
                Text("\(store.tasks(in: group).count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.vertical, 5).padding(.leading, 8)
                .draggable("group:\(group.id)")
        case .task(let task, let depth):
            TodoRow(task: task, depth: depth, hasChildren: store.hasChildren(task),
                    collapsed: store.collapsed.contains(task.title), isAnimatingCompletion: store.animatingCompletion.contains(task.title),
                    isExitingCompletion: store.exitingCompletion.contains(task.title), store: store)
                .draggable("task:\(task.title)")
        }
    }

    @ViewBuilder private func contextMenu(for row: TodoListRow) -> some View {
        switch row {
        case .group(let group):
            Button(store.collapsedGroups.contains(group.id) ? "Expandir grupo" : "Recolher grupo") { store.toggleGroup(group) }
            Button("Excluir grupo", role: .destructive) { store.deleteGroup(group) }
        case .task(let task, _):
            Button(task.completed ? "Reabrir tarefa" : "Concluir tarefa") { store.toggle(task) }
            Menu("Transformar em subtarefa de") {
                Button("Deixar no nível principal") { store.setParent(task, parent: nil) }
                ForEach(store.tasks.filter { $0.title != task.title && !$0.completed }) { parent in
                    Button(parent.title) { store.setParent(task, parent: parent.title) }
                }
            }
            Divider()
            Button("Apagar", role: .destructive) { store.delete(task) }
        }
    }

    private func handleDrop(_ payload: String, on row: TodoListRow, at position: CGFloat) -> Bool {
        if payload.hasPrefix("group:") {
            guard case .group(let target) = row else { return false }
            let sourceID = String(payload.dropFirst("group:".count))
            guard sourceID != target.id, let source = store.groups.first(where: { $0.id == sourceID }) else { return false }
            store.moveGroup(source, before: target, position: position)
            return true
        }
        guard payload.hasPrefix("task:") else { return false }
        let title = String(payload.dropFirst("task:".count))
        guard let source = store.tasks.first(where: { $0.title == title }) else { return false }
        switch row {
        case .group(let group): store.assign(source, to: group.id)
        case .task(let target, _): store.drop(source, on: target, position: position)
        }
        return true
    }

    private func submitSearch() {
        guard store.canCreateSearch else { return }
        let value = store.search
        if store.isCreatingGroup {
            store.addParentTask(value)
        } else {
            store.add(value)
        }
        store.search = ""
        store.isCreatingGroup = false
        searchFocused = true
    }

    private func handleKey(_ event: NSEvent, proxy: ScrollViewProxy) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let control = flags.contains(.control)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if control && event.keyCode == 1 { searchFocused = true; return true }
        let pressedJK = event.keyCode == 38 || event.keyCode == 40
        let commandOnly = flags.intersection([.control, .option, .command]) == .command
        if pressedJK && commandOnly && !searchFocused && !store.isCommandMenu {
            let delta = event.keyCode == 38 ? 1 : -1 // ⌘J desce; ⌘K sobe.
            withAnimation(.easeInOut(duration: 0.2)) { moveSelected(by: delta) }
            if let selectedRowID {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(selectedRowID, anchor: nil)
                    }
                }
            }
            return true
        }
        if store.isCommandMenu && isNavigationKey(event.keyCode, flags: flags) {
            let options = filteredCommands
            guard !options.isEmpty else { return true }
            let delta = event.keyCode == 38 ? 1 : -1
            commandSelection = max(0, min(options.count - 1, commandSelection + delta))
            return true
        }
        if isNavigationKey(event.keyCode, flags: flags) && (navigationKeymap != "none" || !searchFocused) {
            let delta = event.keyCode == 38 ? 1 : -1 // Ctrl+J desce; Ctrl+K sobe.
            if shift { moveSelected(by: delta) }
            else { selectNext(by: delta, proxy: proxy) }
            searchFocused = false
            return true
        }
        if command && (chars == "1" || chars == "2") {
            store.showingCompleted = chars == "2"
            selectedRowID = nil
            return true
        }
        if command && chars == "f" { searchFocused = true; return true }
        if command && shift && chars == "n" {
            store.isCreatingGroup = true
            store.search = ""
            searchFocused = true
            return true
        }
        if command && chars == "n" {
            store.isCreatingGroup = false
            store.search = ""
            searchFocused = true
            return true
        }
        if !searchFocused && chars == "/" {
            store.isCommandMenu = true
            store.isCreatingGroup = false
            store.search = ""
            commandSelection = 0
            searchFocused = true
            return true
        }
        if store.isCommandMenu && event.keyCode == 36 {
            let options = filteredCommands
            if options.indices.contains(commandSelection) { chooseCommand(options[commandSelection]) }
            return true
        }
        if event.keyCode == 53 {
            if store.isCommandMenu || store.isCreatingGroup { store.cancelCommandMode() }
            else if !store.search.isEmpty { store.search = "" }
            else { searchFocused = true; selectedRowID = nil }
            return true
        }
        if !searchFocused && event.keyCode == 36 { activateSelected(); return true }
        if !searchFocused && event.keyCode == 49 { toggleSelectedTask(); return true }
        if command && event.keyCode == 51 { deleteSelected(); return true }
        return false
    }

    private func isNavigationKey(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard keyCode == 38 || keyCode == 40 else { return false } // J / K
        let modifiers = flags.intersection([.control, .option, .command])
        switch navigationKeymap {
        case "none": return modifiers.isEmpty
        default: return modifiers == .control
        }
    }

    private func selectNext(by delta: Int, proxy: ScrollViewProxy) {
        let rows = store.visibleRows
        guard !rows.isEmpty else { return }
        let current = rows.firstIndex(where: { $0.id == selectedRowID })
        let next = max(0, min(rows.count - 1, (current ?? (delta > 0 ? -1 : rows.count)) + delta))
        selectedRowID = rows[next].id
        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(rows[next].id, anchor: .center) }
    }

    private func moveSelected(by delta: Int) {
        guard let selectedRowID, let row = store.visibleRows.first(where: { $0.id == selectedRowID }) else { return }
        switch row {
        case .group(let group): store.moveGroup(group, by: delta)
        case .task(let task, _): store.moveTask(task, by: delta)
        }
    }

    private func activateSelected() {
        guard let selectedRowID, let row = store.visibleRows.first(where: { $0.id == selectedRowID }) else { return }
        switch row {
        case .group(let group): store.toggleGroup(group)
        case .task(let task, _): store.toggle(task)
        }
    }

    private func toggleSelectedTask() {
        guard let selectedRowID, case .task(let task, _)? = store.visibleRows.first(where: { $0.id == selectedRowID }) else { return }
        store.toggle(task)
    }

    private func deleteSelected() {
        guard let selectedRowID, let row = store.visibleRows.first(where: { $0.id == selectedRowID }) else { return }
        switch row {
        case .group(let group): store.deleteGroup(group)
        case .task(let task, _): store.delete(task)
        }
        self.selectedRowID = nil
    }
}

struct KeyboardEventMonitor: NSViewRepresentable {
    let handler: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(handler: handler) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install()
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.handler = handler }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.remove() }

    final class Coordinator {
        var handler: (NSEvent) -> Bool
        private var monitor: Any?
        init(handler: @escaping (NSEvent) -> Bool) { self.handler = handler }
        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.handler(event) else { return event }
                return nil
            }
        }
        func remove() {
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        }
        deinit { remove() }
    }
}

struct TodoRow: View {
    let task: Todo
    let depth: Int
    let hasChildren: Bool
    let collapsed: Bool
    let isAnimatingCompletion: Bool
    let isExitingCompletion: Bool
    @ObservedObject var store: TodoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.tertiary)
            if depth > 0 { Rectangle().fill(Color.accentColor.opacity(0.25)).frame(width: 2).padding(.leading, CGFloat(depth * 18)) }
            Button { store.toggle(task) } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17)).foregroundStyle(task.completed ? Color.green : Color.secondary)
            }.buttonStyle(.plain)
            if hasChildren {
                Button { if collapsed { store.collapsed.remove(task.title) } else { store.collapsed.insert(task.title) } } label: {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            } else { Color.clear.frame(width: 12) }
            Text(task.title)
                .strikethrough(task.completed, pattern: .solid, color: .green)
                .foregroundStyle(task.completed ? Color.green : Color.primary)
                .animation(.easeInOut(duration: 0.28), value: task.completed)
            if let tag = task.tag {
                Text(tag).font(.caption2).padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.10), in: Capsule()).foregroundStyle(.tint)
            }
            Spacer()
        }
        .overlay(alignment: .leading) {
            if isAnimatingCompletion && !reduceMotion { ConfettiBurst().offset(x: 20, y: -3).allowsHitTesting(false) }
        }
        .padding(.vertical, 5).padding(.leading, 8)
        .offset(x: isExitingCompletion ? -560 : 0, y: isExitingCompletion ? -20 : 0)
        .opacity(isExitingCompletion ? 0 : 1)
        .animation(.easeOut(duration: 0.28), value: isExitingCompletion)
        .contentShape(Rectangle())
        .transition(.opacity)
    }
}

struct ConfettiBurst: View {
    @State private var burst = false
    private let colors: [Color] = [.green, .mint, .yellow, .orange, .pink, .cyan]

    var body: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { index in
                let angle = Double(index) * (.pi * 2 / 14)
                let distance: CGFloat = burst ? 25 + CGFloat(index % 3) * 6 : 0
                Capsule()
                    .fill(colors[index % colors.count])
                    .frame(width: index.isMultiple(of: 2) ? 3 : 4, height: index.isMultiple(of: 2) ? 7 : 5)
                    .rotationEffect(.degrees(Double(index * 31)))
                    .offset(x: cos(angle) * distance, y: sin(angle) * distance)
                    .opacity(burst ? 0 : 1)
            }
        }
        .frame(width: 66, height: 58)
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) { burst = true }
        }
    }
}

struct KeymapSettingsView: View {
    @AppStorage("navigationKeymap") private var navigationKeymap = "control"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Keymap", systemImage: "keyboard")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Concluído") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("Configure os atalhos de navegação usados para percorrer a lista e os comandos.")
                .foregroundStyle(.secondary)
            Picker("Navegação J/K", selection: $navigationKeymap) {
                Text("Ctrl + J / Ctrl + K").tag("control")
                Text("J / K (sem modificador)").tag("none")
            }
            .pickerStyle(.radioGroup)
            Divider()
            LabeledContent("Focar busca", value: "Ctrl + S")
            LabeledContent("Alternar listas", value: "⌘ + 1 / ⌘ + 2")
            LabeledContent("Criar tarefa pai", value: "/, depois Group")
            Spacer()
        }
        .padding(22)
        .frame(width: 400, height: 290)
        .onAppear { if navigationKeymap == "option" { navigationKeymap = "control" } }
    }
}

@main struct TodoOrganizerApp: App {
    var body: some Scene {
        WindowGroup("Todo Organizer") { ContentView() }
            .windowStyle(.titleBar)
    }
}
