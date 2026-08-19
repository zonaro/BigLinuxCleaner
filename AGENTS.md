# BigLinuxCleaner — AGENTS.md

> **Projeto**: BigLinuxCleaner — Script de manutenção multi-DE para Big Linux (Arch/Manjaro)
> **Versão**: 2.0 (Multi-DE: KDE Plasma, GNOME, XFCE, Cinnamon)
> **Arquitetura**: Modular Bash ≥ 4 com libs reutilizáveis

---

## 🎯 Visão Geral

O **BigLinuxCleaner** evoluiu de um script focado apenas em KDE Plasma para uma ferramenta **multi-DE** compatível com o ecossistema **BigCommunity** (KDE Plasma, GNOME, XFCE, Cinnamon). A arquitetura é modular, com bibliotecas reutilizáveis para detecção de DE, refresh de menu/cache e detecção de terminais.

---

## 🏗️ Arquitetura

### Padrão Arquitetural
- **Modular Monolith**: Script principal (`cleaner.sh`) + bibliotecas em `lib/`
- **MVC-inspired**: Separação de responsabilidades (detecção, ações, apresentação)
- **DRY**: Funções compartilhadas em libs, sem duplicação de código
- **POSIX-compliant + Bash 4 features** (arrays associativos)

### Estrutura de Diretórios
```
BigLinuxCleaner/
├── lib/
│   ├── detect_de.sh      # Detecção de Desktop Environment
│   ├── refresh_de.sh     # Refresh universal de menu/cache por DE
│   ├── terminals.sh      # Detecção/listagem de terminais
│   ├── cleanup.sh        # Lógica de limpeza (pacman, flatpak, snap, etc)
│   ├── steam_icons.sh    # Correção de ícones da Steam
│   └── ui.sh             # Funções de UI (cores, logs, prompts)
├── cleaner.sh            # Script principal (orquestra as libs)
├── install.sh            # Instalador universal multi-DE
├── docs/                 # Site estático (multi-idioma)
├── AGENTS.md             # Este arquivo
├── .agents/              # Configuração dos agentes
├── README.md             # Documentação principal
├── LICENSE
└── .gitignore
```

### Fluxo Principal (`cleaner.sh`)
```
main()
├── source lib/ui.sh           # Cores, logging
├── source lib/detect_de.sh    # Detecta DE ativo
├── source lib/cleanup.sh      # Funções de limpeza
├── source lib/steam_icons.sh  # Correção Steam
├── source lib/refresh_de.sh   # Refresh específico do DE
├── parse_args()               # --dry-run, --json, etc
├── run_cleanup()              # Orquestra limpezas
└── refresh_de()               # Atualiza menu/cache do DE detectado
```

---

 
## 📋 Regras do Projeto

### Gerais (herdadas de `~/.config/code/user/instructions/lobby-team.instructions.md`)
- ✅ **README.md** obrigatório com descrição, instalação, uso
- ✅ **AGENTS.md** obrigatório (este arquivo)
- ✅ **.gitignore** apropriado
- ✅ **i18n**: pt-BR (foco), EN, ES
- ✅ **MVC** para backend/APIs
- ✅ **Performance, Acessibilidade, UX, QoL**
- ✅ **DRY** — evitar duplicação, promover reutilização
- ✅ **MySQL/MariaDB** para bancos (não aplicável aqui — sem DB)
- ✅ **Responsivo, mobile-first** (site/docs)
- ✅ **Otimização para telas grandes** (TVs, ultrawide)

### Específicas do BigLinuxCleaner

#### Bash / Shell
- **Bash ≥ 4** (arrays associativos obrigatórios)
- **set -Eeuo pipefail** em todos os scripts
- **Funções prefixadas** por domínio: `de_detect_*`, `de_refresh_*`, `term_*`, `cleanup_*`, `steam_*`, `ui_*`
- **Namespace de variáveis**: `BLC_` prefix para variáveis globais do projeto
- **Tratamento de erros**: `trap` para cleanup, códigos de saída padronizados
- **Compatibilidade**: Arch/Manjaro/Big Linux (pacman, systemd)

#### Detecção de DE (`lib/detect_de.sh`)
- **Prioridade**: `$XDG_CURRENT_DESKTOP` → `$DESKTOP_SESSION` → processos ativos → fallback "unknown"
- **DEs suportados**: `kde`, `gnome`, `xfce`, `cinnamon`, `unknown`
- **Retorno**: Código do DE (string) + variáveis exportadas `BLC_DE`, `BLC_DE_VERSION`
- **Testável**: Função pura, sem side effects

#### Refresh Universal (`lib/refresh_de.sh`)
- **API**: `de_refresh_menu()`, `de_refresh_icon_cache()`, `de_restart_shell()`
- **Por DE**: Implementação específica + fallback genérico
- **Não-bloqueante**: Falha no refresh não para o script principal
- **Logging**: Usa `ui_log_*` de `lib/ui.sh`

#### Terminais (`lib/terminals.sh`)
- **Detecção**: Lista terminais instalados (não prioriza KDE)
- **Interativo**: Pergunta ao usuário qual usar (com default sensato)
- **Fallback**: `$TERM`, `$TERMINAL`, processo pai, `xdg-terminal-exec`
- **Desktop Entry**: `Terminal=true` genérico + `Exec` com terminal detectado

#### Instalador (`install.sh`)
- **Modo interativo**: Pergunta local (Desktop/Menu/Ambos) + terminal
- **Modo não-interativo**: Flags `--menu`, `--desktop`, `--terminal=xxx`, `--yes`
- **Desinstalação**: `--uninstall` remove tudo (atalho, ícone, script local)
- **Offline-first**: Copia script local se sem internet

#### Limpeza (`lib/cleanup.sh`)
- **Módulos independentes**: `cleanup_orphans`, `cleanup_broken_desktop`, `cleanup_flatpak`, `cleanup_snap`, `cleanup_steam_icons`, `cleanup_cache`
- **Dry-run**: `--dry-run` mostra o que faria sem executar
- **Relatório**: JSON/HTML opcional (`--report=json|html`)

#### Site/Docs (`docs/`)
- **Tema**: Dark navy + azul/ciano (paleta Big Linux)
- **i18n**: `data-i18n` attributes + JS para troca de idioma
- **SEO**: meta tags, JSON-LD, sitemap.xml, robots.txt
- **Performance**: CSS/JS minificados, imagens otimizadas

---

## 🔧 Configuração dos Agentes (`.agents/`)

Cada agente tem seu arquivo `.agent.md` em `.agents/` com:
- `name`, `emoji`, `model`, `specialty`
- `handoffs` para transições guiadas
- `tools` permitidos/restritos
- `instructions` específicas do projeto

---

## 🚀 Backlog de Funcionalidades (Preparação Arquitetural)

| Feature                      | Status      | Integração                                  |
| ---------------------------- | ----------- | ------------------------------------------- |
| `journalctl` vacuum          | 📋 Planejado | `lib/cleanup.sh` → `cleanup_journal()`      |
| `paccache` (pacman cache)    | 📋 Planejado | `lib/cleanup.sh` → `cleanup_pacman_cache()` |
| Thumbnails cache             | 📋 Planejado | `lib/cleanup.sh` → `cleanup_thumbnails()`   |
| Trash (lixeira)              | 📋 Planejado | `lib/cleanup.sh` → `cleanup_trash()`        |
| AUR helpers (yay/paru/pamac) | 📋 Planejado | `lib/cleanup.sh` → `cleanup_aur()`          |
| Disk space alert (>85%)      | 📋 Planejado | `lib/cleanup.sh` → `check_disk_space()`     |
| `--dry-run` mode             | 📋 Planejado | `cleaner.sh` → `parse_args()` + flags       |
| JSON/HTML report             | 📋 Planejado | `lib/ui.sh` → `ui_report_*()`               |
| Systemd timer                | 📋 Planejado | `install.sh` → `--enable-timer`             |
| **GUI BashView** (Big Linux) | 📋 Planejado | Nova entry point `cleaner-gui.sh` usa libs  |

---

## 📝 Convenções de Código

### Naming
```bash
# Funções: domínio_ação
de_detect_current()
de_refresh_menu()
term_list_available()
cleanup_orphans()
steam_fix_icons()
ui_log_info()

# Variáveis globais: BLC_SCREAMING_SNAKE
BLC_DE="kde"
BLC_DE_VERSION="6"
BLC_DRY_RUN=false
BLC_REPORT_FORMAT=""

# Constantes: UPPER_SNAKE no escopo da lib
readonly DE_KDE="kde"
readonly DE_GNOME="gnome"
```

### Logging (via `lib/ui.sh`)
```bash
ui_log_info "Mensagem informativa"
ui_log_ok "Sucesso"
ui_log_warn "Aviso"
ui_log_err "Erro"
ui_log_debug "Debug"  # só se BLC_DEBUG=1
```

### Error Handling
```bash
# Retorna 0=sucesso, 1=erro esperado, 2=erro crítico
cleanup_orphans() {
    command -v pacman >/dev/null || return 1  # não disponível = não é erro
    # ...
}
```

 

## ✅ Checklist de Validação (por release)

- [ ] `shellcheck` passa em todos `.sh`
- [ ] `bash -n` (syntax check) em todos `.sh`
- [ ] Testado em: KDE Plasma 5/6, GNOME 45+, XFCE 4.18+, Cinnamon 6+
- [ ] `install.sh --uninstall` limpa tudo corretamente
- [ ] `--dry-run` não faz alterações
- [ ] Site `docs/` valida HTML5, CSS, JS
- [ ] i18n: pt-BR, EN, ES completos
- [ ] README.md atualizado
- [ ] CHANGELOG.md atualizado

---

## 📚 Referências

- [InnerFormValidation](https://github.com/zonaro/InnerFormValidation) — validação/máscaras (para GUI BashView futura)
- [NameToColor](https://github.com/zonaro/NameToColor) — paletas CSS (site/docs)
- [Big Linux](https://biglinux.com.br) — distro base
- [freedesktop.org specs](https://specifications.freedesktop.org/) — `.desktop`, `xdg-*`, icon theme
- [Arch Wiki - Desktop Entries](https://wiki.archlinux.org/title/Desktop_entries)