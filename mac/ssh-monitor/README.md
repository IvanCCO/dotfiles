# SSH Monitor

Aplicação nativa SwiftUI para a barra de menus do macOS 13 ou superior.

## Usar

Abra `dist/SSH Monitor.app`. Selecione um alias no menu superior. A lista vem de `~/.ssh/config` e `/etc/ssh/ssh_config`, incluindo arquivos Include. A seleção é lembrada na próxima abertura.

O app usa `/usr/bin/ssh` e a configuração/chaves existentes. Requer autenticação não interativa (chave disponível ou carregada no ssh-agent) e host já conhecido pelo SSH. Não salva senhas nem desativa a verificação de host. Para preparar uma conexão nova, conecte uma vez pelo Terminal: `ssh nome-do-alias`.

O Fedora precisa de Python 3. O coletor é enviado pela entrada padrão de uma sessão SSH persistente; não instala arquivos ou serviços remotos. GPU requer driver NVIDIA e a biblioteca NVML (`libnvidia-ml.so.1`) ou `nvidia-smi` acessível no PATH remoto. Quando o comando não está instalado, o coletor usa diretamente NVML via ctypes, sem dependências Python externas. Sem isso, CPU, RAM e processos continuam disponíveis.

Métricas atualizadas a cada 2 segundos. CPU global é normalizada entre 0 e 100%; CPU de um processo pode ultrapassar 100% quando usa vários núcleos. A memória dos processos corresponde ao RSS em MiB; a memória do sistema é MemTotal menos MemAvailable, apresentada em GiB. Até 20 processos são exibidos, ordenados por CPU ou memória. A GPU apresentada é a primeira retornada pelo nvidia-smi.

O círculo verde indica recebimento recente de dados. Uma conexão encerrada ou sem dados por 15 segundos deixa de aparecer como conectada. Use o botão de reconexão para tentar novamente. O app coleta enquanto está aberto, mesmo com o painel fechado. O seletor de máquina aparece apenas quando há mais de um alias. O painel segue o tema do macOS, usando Liquid Glass nativo (NSGlassEffectView) no macOS 26+, com fallback para material de popover em versões anteriores, barras com texto interno, seletor segmentado e switch. O menu de opções no rodapé permite reconectar, recarregar máquinas e reiniciar o app.

## Compilar

```sh
./scripts/build-app.sh
```

Gera um app com assinatura local ad hoc em `dist`. Requer as Command Line Tools do Xcode e Python 3 para os scripts de build/testes. Não requer projeto Xcode, dependências externas ou conta Apple Developer.

## Verificar coletor

```sh
./scripts/test.sh
```

A conexão real deve ser verificada no Mac com acesso à rede da máquina remota.

O script aplica um overlay local caso as Command Line Tools contenham duas definições de SwiftBridging. Nenhum arquivo de sistema é alterado.

A barra SWAP mostra apenas swap em disco (NVMe); zram é exibida separadamente. O ícone usa a cor padrão do sistema normalmente, amarelo quando a RAM usada ultrapassa 12 GiB e vermelho quando há swap em disco ocupado, com prioridade sobre amarelo. Páginas em swap podem continuar ocupadas após a pressão de memória diminuir; o vermelho indica ocupação, não comprova falta de RAM naquele instante.

## Aparência e privacidade

Cores semânticas e fontes do sistema seguem o tema claro/escuro. As barras e a lista têm uma base mais opaca para preservar contraste sobre o vidro. Reduzir Transparência e Aumentar Contraste ativam um fundo sólido. A ponte Objective-C usa apenas a API pública NSGlassEffectView, carregada em runtime para permitir builds com SDKs anteriores ao macOS 26.

O repositório contém somente código, testes e instruções. Não copie configurações SSH, chaves, arquivos .env, logs, snapshots ou binários para o Git. O app lê os aliases localmente e salva a seleção apenas em UserDefaults.
