# BigLinuxCleaner

Script Bash para limpeza e manutenção do **Big Linux** e **BigCommunity** (sistemas baseados em Arch/Manjaro com **KDE Plasma, GNOME, XFCE, Cinnamon**). Ele realiza as seguintes tarefas automaticamente:

- **Remove pacotes órfãos** via `pacman` (pacotes instalados como dependência que não são mais necessários).
- **Limpa atalhos quebrados** (`.desktop`) no menu de aplicativos — verifica entradas inválidas nos diretórios do sistema, do usuário, do Flatpak e do Snap.
- **Corrige ícones da Steam** — detecta atalhos da Steam com ícones faltando ou com resolução insuficiente e baixa o ícone correto automaticamente a partir do ID do jogo na CDN da Steam.
- **Remove atalhos de apps Flatpak desinstalados** cruzando os arquivos `.desktop` com a lista de aplicativos instalados.
- **Remove atalhos de apps Snap desinstalados** de forma semelhante.
- **Limpa o cache do Flatpak** (cache local do usuário e cache global) e remove runtimes/pacotes sem uso.
- **Limpa revisões desabilitadas do Snap** e o cache do daemon.
- **Atualiza o menu e o cache do Desktop Environment** automaticamente:
  - **KDE Plasma**: `kbuildsycoca`, `krunner`, `plasmashell`
  - **GNOME**: `update-desktop-database`, `gtk-update-icon-cache`, `gnome-shell` restart
  - **XFCE**: `xfce4-panel -r`, `update-desktop-database`, `gtk-update-icon-cache`
  - **Cinnamon**: `cinnamon-settings-daemon` restart, `update-desktop-database`, `gtk-update-icon-cache`
 
 ---

## Instalação

Execute o instalador diretamente do GitHub, sem clonar o repositório:

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash
```

> **Atenção:** sempre inspecione scripts antes de executá-los com privilégios. Você pode visualizar o conteúdo completo em [`install.sh`](./install.sh) e [`cleaner.sh`](./cleaner.sh).

### App gráfico (padrão)

A instalação padrão cria um atalho (**Área de trabalho**, **Menu de aplicativos** ou ambos) que abre o **app gráfico do BigLinuxCleaner** — uma interface BigBashView nativa do Big Linux, sem depender de navegador:

- **Seleção de tarefas**: escolha exatamente o que limpar antes de executar;
- **Progresso ao vivo**: barra de progresso, contadores e estatísticas atualizados em tempo real durante a limpeza;
- **Log de execução**: saída detalhada exibida linha a linha enquanto o script roda;
- **Ícone oficial** instalado em múltiplos tamanhos (256/128/64 px);
- **Menu atualizado automaticamente** ao final da instalação.

O instalador pergunta onde você quer o atalho e instala tudo em `~/.local/share/BigLinuxCleaner/`. O app gráfico requer o **BigBashView** (`bigbashview`), presente por padrão no Big Linux; em outros sistemas o atalho abre automaticamente a versão de terminal.

Para remover tudo (atalhos, ícone, GUI e script local):

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash -s -- --uninstall
```

### Modo não-interativo (para automação)

```bash
# Instala apenas no menu
./install.sh --menu

# Instala apenas na área de trabalho
./install.sh --desktop

# Define terminal específico (usado pelo modo CLI do atalho)
./install.sh --terminal=gnome-terminal

# Modo silencioso (usa padrões: ambos + terminal preferido do DE)
./install.sh --yes
```

## Uso pelo terminal (alternativo)

Se preferir não instalar nada, execute a limpeza direto no terminal sem clonar o repositório:

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/cleaner.sh | bash
```

Ou manualmente a partir do código-fonte:

```bash
git clone https://github.com/zonaro/BigLinuxCleaner.git
cd BigLinuxCleaner
chmod +x cleaner.sh
./cleaner.sh
```

## Requisitos

| Ferramenta                | Obrigatória | Observação                                 |
| ------------------------- | ----------- | ------------------------------------------ |
| `bash` ≥ 4                | ✅           | Necessário para arrays associativos        |
| `pacman`                  | ✅           | Limpeza de órfãos (Arch/BigLinux)          |
| `sudo`                    | ✅           | Remoção de arquivos em `/usr` e `/var`     |
| `curl`                    | ✅           | Download de ícones da Steam                |
| `bigbashview`             | ⬜           | App gráfico (padrão no Big Linux)          |
| `flatpak`                 | ⬜           | Ignorado se não encontrado                 |
| `snap`                    | ⬜           | Ignorado se não encontrado                 |
| `kbuildsycoca5`/`6`       | ⬜           | Atualização do KDE (ignorado se ausente)   |
| `convert`                 | ⬜           | ImageMagick — converte ícones para PNG     |
| `xdg-terminal-exec`       | ⬜           | Padrão freedesktop para abrir terminal     |
| `gtk-update-icon-cache`   | ⬜           | Cache de ícones GTK (GNOME/XFCE/Cinnamon)  |
| `update-desktop-database` | ⬜           | Banco de dados de aplicações (freedesktop) |

## Desktop Environments Suportados

| DE                        | Status   | Refresh de Menu/Cache                                                          |
| ------------------------- | -------- | ------------------------------------------------------------------------------ |
| **KDE Plasma**            | ✅ Total  | `kbuildsycoca`, `plasmashell`, `krunner`                                       |
| **GNOME**                 | ✅ Total  | `update-desktop-database`, `gtk-update-icon-cache`, `gnome-shell`              |
| **XFCE**                  | ✅ Total  | `xfce4-panel -r`, `update-desktop-database`, `gtk-update-icon-cache`           |
| **Cinnamon**              | ✅ Total  | `cinnamon-settings-daemon`, `update-desktop-database`, `gtk-update-icon-cache` |
| Outros (MATE, LXQt, etc.) | ⚠️ Básico | `update-desktop-database`, `gtk-update-icon-cache` (genérico)                  |

## Arquitetura Modular

```
BigLinuxCleaner/
├── lib/
│   ├── detect_de.sh      # Detecção de Desktop Environment
│   ├── refresh_de.sh     # Refresh universal de menu/cache por DE
│   └── terminals.sh      # Detecção/listagem de terminais
├── cleaner.sh            # Script principal (orquestra as libs)
├── install.sh            # Instalador universal multi-DE (GUI + CLI)
├── gui/                  # App gráfico BigBashView (progresso ao vivo)
│   ├── index.sh.html     # Tela principal (seleção de tarefas)
│   ├── run_cleanup.sh    # Backend: sessão, worker e página de progresso
│   └── tail_log.sh.html  # Endpoint incremental do log de execução
├── docs/                 # Site estático (multi-idioma)
├── AGENTS.md             # Regras do projeto
├── .agents/              # Configuração dos agentes
├── README.md
├── LICENSE
└── .gitignore
```

## Licença

Distribuído sob a licença MIT. Consulte o arquivo [LICENSE](./LICENSE) para mais detalhes.
