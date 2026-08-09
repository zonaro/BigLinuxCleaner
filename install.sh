#!/bin/bash
#
# install.sh — Instala o BigLinuxCleaner como atalho (.desktop) no sistema.
#
# Cria um atalho (Área de trabalho e/ou Menu de aplicativos) que executa o
# cleaner.sh direto do GitHub e instala o ícone oficial (icon.svg).
#
# Uso:
#   ./install.sh              Instala (pergunta onde criar o atalho)
#   ./install.sh --uninstall  Remove o atalho e o ícone instalados
#
# Também pode ser executado direto do GitHub:
#   curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash

set -uo pipefail

CLEANER_URL="https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/cleaner.sh"
ICON_URL="https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/icon.svg"

DESKTOP_ID="biglinuxcleaner.desktop"
ICON_ID="biglinuxcleaner.svg"

MENU_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERRO]${NC} $*"; }

# Descobre o diretório da Área de trabalho (respeita pastas localizadas).
get_desktop_dir() {
    local d
    if command -v xdg-user-dir >/dev/null 2>&1; then
        d="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
        if [[ -n "$d" && -d "$d" ]]; then
            echo "$d"
            return 0
        fi
    fi
    for d in "$HOME/Desktop" "$HOME/Área de Trabalho"; do
        if [[ -d "$d" ]]; then
            echo "$d"
            return 0
        fi
    done
    echo "$HOME/Desktop"
}

# Gera o conteúdo do arquivo .desktop (Exec roda o cleaner direto do GitHub).
build_desktop_content() {
    cat <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=BigLinuxCleaner
GenericName=Limpeza do sistema
Comment=Limpa atalhos quebrados, órfãos do pacman/flatpak/snap e o cache do KDE Plasma
Exec=sh -c "curl -fsSL $CLEANER_URL | bash; echo; read -rp \"Pressione Enter para fechar...\""
Icon=biglinuxcleaner
Terminal=true
Categories=System;
Keywords=cleaner;limpeza;pacman;flatpak;snap;kde;atalhos;
StartupNotify=false
EOF
}

install_icon() {
    mkdir -p "$ICON_DIR"

    if [[ -f "icon.svg" ]]; then
        cp -f "icon.svg" "$ICON_DIR/$ICON_ID"
    elif command -v curl >/dev/null 2>&1; then
        log_info "Baixando o ícone do GitHub..."
        curl -fsSL "$ICON_URL" -o "$ICON_DIR/$ICON_ID" || {
            log_err "Falha ao baixar o ícone de $ICON_URL"
            return 1
        }
    else
        log_err "Ícone 'icon.svg' não encontrado e 'curl' não está disponível."
        return 1
    fi

    [[ -s "$ICON_DIR/$ICON_ID" ]] || {
        log_err "Ícone instalado parece vazio/corrompido."
        return 1
    }
    log_ok "Ícone instalado em $ICON_DIR/$ICON_ID"
}

write_desktop() {
    local target="$1"
    mkdir -p "$(dirname "$target")"
    build_desktop_content > "$target"
    chmod +x "$target"
    log_ok "Atalho criado: $target"
}

install_shortcut() {
    local install_menu="$1" install_desktop="$2"

    install_icon || return 1

    if [[ "$install_menu" == 1 ]]; then
        mkdir -p "$MENU_DIR"
        write_desktop "$MENU_DIR/$DESKTOP_ID"
    fi

    if [[ "$install_desktop" == 1 ]]; then
        local desktop_dir
        desktop_dir="$(get_desktop_dir)"
        mkdir -p "$desktop_dir"
        write_desktop "$desktop_dir/$DESKTOP_ID"
    fi
}

refresh_menu() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$MENU_DIR" >/dev/null 2>&1 || true
    fi
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    elif command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
    fi
}

uninstall() {
    local desktop_dir removed=0
    desktop_dir="$(get_desktop_dir)"

    for f in "$MENU_DIR/$DESKTOP_ID" "$desktop_dir/$DESKTOP_ID"; do
        if [[ -f "$f" ]]; then
            rm -f "$f" && ((removed += 1))
        fi
    done

    if [[ -f "$ICON_DIR/$ICON_ID" ]]; then
        rm -f "$ICON_DIR/$ICON_ID" && ((removed += 1))
    fi

    refresh_menu

    if ((removed > 0)); then
        log_ok "Atalho e ícone do BigLinuxCleaner removidos."
    else
        log_warn "Nada para remover — o BigLinuxCleaner não estava instalado."
    fi
}

ask_install_location() {
    local choice
    # Menu exibido para o usuário vai para stderr para não poluir o resultado.
    echo >&2
    echo >&2 "Onde deseja instalar o atalho do BigLinuxCleaner?"
    echo >&2 "  1) Área de trabalho"
    echo >&2 "  2) Menu de aplicativos"
    echo >&2 "  3) Ambos (padrão)"
    echo >&2

    # Quando o script roda via `curl ... | bash`, o stdin é um pipe (não um
    # terminal) e o `read` encontra EOF na hora. Nesse caso, lemos do /dev/tty.
    if [[ -t 0 ]]; then
        read -rp "Escolha [1/2/3]: " choice
    elif [[ -r /dev/tty ]]; then
        read -rp "Escolha [1/2/3]: " choice < /dev/tty
    else
        log_err "Sem terminal interativo — não foi possível ler a resposta." >&2
        return 1
    fi

    choice="${choice:-3}"
    case "$choice" in
        1) echo "0 1" ;; # menu desktop
        2) echo "1 0" ;;
        3) echo "1 1" ;;
        *) log_err "Opção inválida: $choice" >&2; return 1 ;;
    esac
}

main() {
    if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
        uninstall
        exit 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_warn "'curl' não encontrado — o atalho não conseguirá executar o cleaner."
    fi

    log_info "Instalando o BigLinuxCleaner como atalho no sistema..."

    local loc menu desktop
    loc="$(ask_install_location)" || exit 1
    read -r menu desktop <<<"$loc"

    install_shortcut "$menu" "$desktop" || exit 1
    refresh_menu

    echo
    log_ok "Instalação concluída!"
    log_info "O atalho roda o cleaner direto do GitHub: $CLEANER_URL"
    log_info "Para remover depois, execute: ./install.sh --uninstall"
}

main "$@"
