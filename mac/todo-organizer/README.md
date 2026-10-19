# Todo Organizer

App nativo para organizar tarefas, reordenar e criar subtarefas. Um `Group` é uma tarefa pai comum, que pode conter tarefas filhas. Os dados ficam em `~/Library/Application Support/Todo Organizer/`. Se a antiga lista do Raycast não estiver mais no disco, o app restaura a última lista observada nesta sessão: 19 tarefas a fazer e 25 concluídas.

## Uso

- O app instalado fica em `~/Applications/Todo Organizer.app`.
- Use o único campo para buscar tarefas. Se o título exato ainda não existir, pressione Enter ou clique em **Criar tarefa** para adicioná-lo.
- Digite `/` para apenas abrir o seletor de comandos disponíveis. Escolha `Group` para criar uma tarefa pai ou `Keymap` para abrir as configurações de atalhos. Apagar `/` retorna à busca. Depois de criar a tarefa pai, arraste tarefas para o centro dela para transformá-las em subtarefas.
- O seletor de comandos é compacto e aparece abaixo da posição de digitação. Ao concluir, a tarefa ganha o risco verde e confetes; em seguida, desliza para a esquerda e para cima com fade, e as linhas abaixo reorganizam-se suavemente. A preferência de movimento reduzido do macOS troca a celebração por uma saída mais discreta.
- Os ícones à direita alternam entre tarefas a fazer e concluídas.
- Arraste uma linha e solte junto à borda superior/inferior de outra para ajustar a ordem.
- Solte no centro de outra tarefa para torná-la subtarefa. O menu de contexto também permite escolher a tarefa-pai ou devolver a tarefa ao nível principal.
- Use a seta da tarefa-pai para recolher/expandir as subtarefas.
- Marque a tarefa para concluir ou reabrir.

### Teclado

- `Ctrl+J` / `Ctrl+K`: descer / subir pela lista e navegar pelo seletor de comandos. O atalho de navegação é configurável em `/` → `Keymap`.
- `⌘+J` / `⌘+K`: mover a tarefa selecionada para baixo / cima na ordem da lista; a seleção acompanha a tarefa.
- `Enter`: recolher/expandir uma tarefa com subtarefas ou concluir/reabrir a tarefa selecionada; no campo, cria o item digitado.
- `Espaço`: concluir/reabrir a tarefa selecionada.
- `/`: abrir os comandos disponíveis.
- `⌘+1` / `⌘+2`: abrir tarefas a fazer / concluídas.
- `Ctrl+S` / `⌘+N`: focar o campo de busca / criação de tarefa.
- `⌘+F`: focar busca; `Esc`: limpar busca ou fechar o seletor.
- `⌘+Backspace`: apagar o item selecionado.

## Compilar no macOS

Compile no macOS com `swiftc -parse-as-library -o /private/tmp/TodoOrganizer -framework SwiftUI -framework AppKit Sources/main.swift`.

O app armazena a lista localmente e não envia dados para serviços externos.
