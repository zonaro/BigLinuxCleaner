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

Execute o script diretamente no terminal sem precisar clonar o repositório:

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/cleaner.sh | bash
```

> **Atenção:** sempre inspecione scripts antes de executá-los com privilégios. Você pode visualizar o conteúdo completo em [`cleaner.sh`](./cleaner.sh).

## Instalação como atalho (.desktop)

Crie um atalho no seu ambiente (área de trabalho e/ou menu de aplicativos) que executa o `cleaner.sh` direto do GitHub — sem precisar clonar o repositório. O instalador **detecta terminais disponíveis no sistema**, lista as opções e **pergunta qual usar** (com sugestão nativa do seu DE: Konsole no KDE, GNOME Terminal no GNOME/Cinnamon, XFCE Terminal no XFCE, etc.). O atalho abre no terminal escolhido, roda a limpeza e fica aberto até você pressionar Enter.

```bash
# A partir do repositório clonado
./install.sh

# Ou diretamente do GitHub
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash
```

O instalador pergunta onde você quer o atalho (**Área de trabalho**, **Menu de aplicativos** ou **ambos**), qual terminal usar, instala o ícone oficial (PNG em múltiplos tamanhos: 256/128/64 px) e atualiza o menu do seu Desktop Environment automaticamente.

Para remover o atalho, o ícone e o script local (também direto do GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash -s -- --uninstall
```

### Modo não-interativo (para automação)

```bash
# Instala apenas no menu
./install.sh --menu

# Instala apenas na área de trabalho
./install.sh --desktop

# Define terminal específico
./install.sh --terminal=gnome-terminal

# Modo silencioso (usa padrões: ambos + terminal preferido do DE)
./install.sh --yes
```

## Uso manual

```bash
# Clone o repositório
git clone https://github.com/zonaro/BigLinuxCleaner.git
cd BigLinuxCleaner

# Torne o script executável e execute
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
├── install.sh            # Instalador universal multi-DE
├── gui/                  # GUI em BashView (futuro)
├── docs/                 # Site estático (multi-idioma)
├── AGENTS.md             # Regras do projeto
├── .agents/              # Configuração dos agentes
├── README.md
├── LICENSE
└── .gitignore
```

## Licença

Distribuído sob a licença MIT. Consulte o arquivo [LICENSE](./LICENSE) para mais detalhes.
