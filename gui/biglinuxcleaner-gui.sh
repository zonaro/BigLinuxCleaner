#!/bin/bash
#
# biglinuxcleaner-gui.sh — Launcher da GUI BigLinuxCleaner
# Compatível com BigCommunity (KDE, GNOME, XFCE, Cinnamon)
#
# Uso:
#   ./biglinuxcleaner-gui.sh          # Abre a GUI (BigBashView)
#   ./biglinuxcleaner-gui.sh --cli    # Executa no terminal (modo CLI)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)"

# Detecta se está no repo ou instalado:
#   Repo:      gui/biglinuxcleaner-gui.sh  → SCRIPT_DIR=repo/gui, GUI_DIR=repo/gui
#   Instalado: ~/.local/share/BigLinuxCleaner/gui/biglinuxcleaner-gui.sh
#              → GUI_DIR = mesmo diretório do script
GUI_DIR="$SCRIPT_DIR"

# Lib e cleaner estão um nível acima
INSTALL_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$INSTALL_BASE/lib"
CLEANER="$INSTALL_BASE/cleaner.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERRO]${NC} $*"; }

if [[ -f "$LIB_DIR/detect_de.sh" ]]; then
    source "$LIB_DIR/detect_de.sh"
    detect_desktop_environment
fi

find_bigbashview() {
    if command -v bigbashview >/dev/null 2>&1; then
        echo "bigbashview"; return 0
    fi
    if command -v bigbashview.py >/dev/null 2>&1; then
        echo "bigbashview.py"; return 0
    fi
    local path
    for path in /usr/bin/bigbashview /usr/bin/bigbashview.py \
                "$HOME/.local/bin/bigbashview" "$HOME/.local/bin/bigbashview.py"; do
        if [[ -x "$path" ]]; then
            echo "$path"; return 0
        fi
    done
    return 1
}

try_install_bigbashview() {
    log_info "BigBashView não encontrado. Tentando instalar via pip..."
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user bigbashview 2>/dev/null && return 0
    fi
    if command -v pip >/dev/null 2>&1; then
        pip install --user bigbashview 2>/dev/null && return 0
    fi
    log_warn "Não foi possível instalar BigBashView automaticamente."
    log_info "Instale manualmente: sudo pacman -S bigbashview"
    return 1
}

run_cli() {
    local de_name="${DESKTOP_ENVIRONMENT_PRETTY:-${DESKTOP_ENVIRONMENT:-desconhecido}}"
    log_info "BigLinuxCleaner CLI — $de_name"
    if [[ -f "$CLEANER" ]]; then
        bash "$CLEANER"
    else
        log_err "cleaner.sh não encontrado em $CLEANER"
        return 1
    fi
}

run_gui() {
    if [[ ! -f "$GUI_DIR/execute_demo" ]]; then
        log_err "Arquivos da GUI não encontrados em $GUI_DIR"
        log_warn "Fallback para modo CLI..."
        run_cli; return
    fi

    local bbv
    if ! bbv="$(find_bigbashview)"; then
        if ! try_install_bigbashview; then
            log_warn "Fallback para modo CLI..."
            run_cli; return
        fi
        bbv="$(find_bigbashview)" || {
            log_err "BigBashView instalado mas não encontrado no PATH."
            run_cli; return
        }
    fi

    log_info "Iniciando GUI do BigLinuxCleaner via BigBashView..."
    chmod +x "$GUI_DIR/execute_demo"
    exec bash "$GUI_DIR/execute_demo"
}

main() {
    case "${1:-}" in
        --cli|-c)  run_cli ;;
        --gui|-g)  run_gui ;;
        --help|-h)
            cat <<'EOF'
BigLinuxCleaner GUI — Interface gráfica para limpeza do sistema

Uso: biglinuxcleaner-gui.sh [opções]

Opções:
  --gui, -g       Abre a interface gráfica (padrão)
  --cli, -c       Executa no terminal (modo CLI)
  --help, -h      Mostra esta ajuda
EOF
            ;;
        *)  run_gui ;;
    esac
}

main "$@"
