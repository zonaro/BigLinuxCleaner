#!/bin/bash
#
# install.sh — Instala o BigLinuxCleaner como atalho (.desktop) no sistema.
# Compatível com BigCommunity: KDE Plasma, GNOME, XFCE, Cinnamon
#
# Instala uma cópia local do cleaner.sh em ~/.local/share/BigLinuxCleaner/
# e cria um atalho (Área de trabalho e/ou Menu de aplicativos) que executa
# o script local. Se online, o cleaner tenta se auto-atualizar a cada
# execução. Se offline, roda a versão em cache sem tentar baixar ícones
# da Steam. Também instala o ícone oficial em PNG (256/128/64 px).
#
# Uso:
#   ./install.sh              Instala (pergunta onde criar o atalho + terminal)
#   ./install.sh --uninstall  Remove o atalho, ícone e script local
#   ./install.sh --menu       Instala apenas no menu (não-interativo)
#   ./install.sh --desktop    Instala apenas na área de trabalho (não-interativo)
#   ./install.sh --terminal=konsole  Define terminal (não-interativo)
#   ./install.sh --yes        Aceita padrões sem perguntar
#
# Também pode ser executado direto do GitHub:
# curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash

set -uo pipefail

RAW_BASE="https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main"
CLEANER_URL="$RAW_BASE/cleaner.sh"
ICON_URL="$RAW_BASE/icon.svg"

DESKTOP_ID="biglinuxcleaner.desktop"
ICON_NAME="biglinuxcleaner"
ICON_SIZES=(256 128 64)

# Diretório local para instalação do script
LOCAL_INSTALL_DIR="$HOME/.local/share/BigLinuxCleaner"
LOCAL_CLEANER="$LOCAL_INSTALL_DIR/cleaner.sh"
LOCAL_GUI_DIR="$LOCAL_INSTALL_DIR/gui"

MENU_DIR="$HOME/.local/share/applications"
HICOLOR_DIR="$HOME/.local/share/icons/hicolor"
SVG_ICON_DIR="$HICOLOR_DIR/scalable/apps"

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

# ─── Carrega biblioteca de terminais ───
LIB_DIR="$(dirname "${BASH_SOURCE[0]:-}")/lib"
if [[ -f "$LIB_DIR/terminals.sh" ]]; then
    source "$LIB_DIR/terminals.sh"
else
    # Fallback se lib não existir
    detect_available_terminals() { return 1; }
    choose_terminal_interactive() { return 1; }
    generate_desktop_exec_line() { return 1; }
fi

# ─── Descobre o diretório da Área de trabalho ───
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

# ─── Garante tema hicolor ───
ensure_hicolor_theme() {
    if [[ -f "$HICOLOR_DIR/index.theme" ]]; then
        return 0
    fi
    mkdir -p "$HICOLOR_DIR"
    cat > "$HICOLOR_DIR/index.theme" <<'THEME'
[Icon Theme]
Name=Hicolor
Comment=Fallback icon theme
Hidden=true
Directories=256x256/apps,128x128/apps,64x64/apps,scalable/apps
[256x256/apps]
Size=256
Type=Fixed
Context=Applications
[128x128/apps]
Size=128
Type=Fixed
Context=Applications
[64x64/apps]
Size=64
Type=Fixed
Context=Applications
[scalable/apps]
Size=128
Type=Scalable
Context=Applications
THEME
}

# ─── Atualiza cache de ícones ───
refresh_icon_cache() {
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$HICOLOR_DIR" >/dev/null 2>&1 || true
    fi
}

# ─── Instala ícone PNG ───
install_icon() {
    local size dir url

    ensure_hicolor_theme

    # Remove ícone SVG de instalações antigas
    if [[ -f "$SVG_ICON_DIR/$ICON_NAME.svg" ]]; then
        rm -f "$SVG_ICON_DIR/$ICON_NAME.svg"
        log_info "Removendo ícone SVG de instalação antiga."
    fi

    for size in "${ICON_SIZES[@]}"; do
        dir="$HICOLOR_DIR/${size}x${size}/apps"
        mkdir -p "$dir"

        if [[ -f "icon-$size.png" ]]; then
            cp -f "icon-$size.png" "$dir/$ICON_NAME.png"
        elif command -v curl >/dev/null 2>&1; then
            url="$RAW_BASE/icon-$size.png"
            log_info "Baixando o ícone (${size}px) do GitHub..."
            curl -fsSL "$url" -o "$dir/$ICON_NAME.png" || {
                log_err "Falha ao baixar o ícone de $url"
                return 1
            }
        else
            log_err "Ícone 'icon-$size.png' não encontrado e 'curl' não está disponível."
            return 1
        fi

        if [[ ! -s "$dir/$ICON_NAME.png" ]]; then
            log_err "Ícone (${size}px) instalado parece vazio/corrompido."
            return 1
        fi
        log_ok "Ícone (${size}px) instalado em $dir/$ICON_NAME.png"
    done

    refresh_icon_cache
}

# ─── Instala cleaner.sh localmente ───
install_cleaner_local() {
    log_info "Instalando script local do BigLinuxCleaner..."
    mkdir -p "$LOCAL_INSTALL_DIR"

    local downloaded=0
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --max-time 10 "$CLEANER_URL" -o "$LOCAL_CLEANER.tmp" 2>/dev/null; then
            if head -n 1 "$LOCAL_CLEANER.tmp" | grep -q '^#!/bin/bash'; then
                mv "$LOCAL_CLEANER.tmp" "$LOCAL_CLEANER"
                chmod +x "$LOCAL_CLEANER"
                log_ok "Script atualizado via GitHub."
                downloaded=1
            fi
            rm -f "$LOCAL_CLEANER.tmp"
        fi
    fi

    if [[ $downloaded -eq 0 ]]; then
        if [[ -f "./cleaner.sh" ]]; then
            cp "./cleaner.sh" "$LOCAL_CLEANER"
            chmod +x "$LOCAL_CLEANER"
            log_ok "Script instalado localmente (cópia do diretório atual)."
        elif [[ -f "$LOCAL_CLEANER" ]]; then
            log_warn "Mantendo versão local existente (sem conexão)."
        else
            log_err "Não foi possível instalar o script."
            return 1
        fi
    fi

    local lib_src
    lib_src="$(dirname "${BASH_SOURCE[0]:-}")/lib"
    if [[ -d "$lib_src" ]]; then
        mkdir -p "$LOCAL_INSTALL_DIR/lib"
        cp "$lib_src"/*.sh "$LOCAL_INSTALL_DIR/lib/" 2>/dev/null || true
        log_ok "Bibliotecas lib/ instaladas."
    fi
}

build_desktop_content() {
    local gui_launcher="$LOCAL_GUI_DIR/biglinuxcleaner-gui.sh"

    cat <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=BigLinuxCleaner
GenericName=Limpeza do sistema
Comment=Limpa atalhos quebrados, órfãos do pacman/flatpak/snap e atualiza o menu do ambiente
Exec=bash ${gui_launcher}
Icon=${ICON_NAME}
Terminal=false
Categories=System;
Keywords=cleaner;limpeza;pacman;flatpak;snap;kde;gnome;xfce;cinnamon;
StartupNotify=false
EOF
}

write_desktop() {
    local target="$1"
    mkdir -p "$(dirname "$target")"
    build_desktop_content > "$target"
    chmod +x "$target"
    log_ok "Atalho criado: $target"
}

install_gui() {
    log_info "Instalando arquivos da GUI BigLinuxCleaner..."
    mkdir -p "$LOCAL_GUI_DIR"

    local gui_src
    gui_src="$(dirname "${BASH_SOURCE[0]:-}")/gui"

    if [[ -d "$gui_src" ]]; then
        cp -r "$gui_src"/* "$LOCAL_GUI_DIR/"
        chmod +x "$LOCAL_GUI_DIR/execute_demo" "$LOCAL_GUI_DIR/biglinuxcleaner-gui.sh" "$LOCAL_GUI_DIR/run_cleanup.sh" 2>/dev/null || true
        log_ok "GUI instalada em $LOCAL_GUI_DIR"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        log_warn "Diretório gui/ não encontrado localmente — tentando download via GitHub..."
        local base_url="$RAW_BASE/gui"
        local files=("execute_demo" "biglinuxcleaner-gui.sh" "run_cleanup.sh" "tail_log.sh.html" "index.sh.html" "css/style.css" "js/app.js")
        local subdirs=("css" "js" "locale")

        for subdir in "${subdirs[@]}"; do
            mkdir -p "$LOCAL_GUI_DIR/$subdir"
        done

        for f in "${files[@]}"; do
            local dir_part
            dir_part="$(dirname "$f")"
            [[ "$dir_part" != "." ]] && mkdir -p "$LOCAL_GUI_DIR/$dir_part"
            curl -fsSL --max-time 10 "$base_url/$f" -o "$LOCAL_GUI_DIR/$f" 2>/dev/null || {
                log_warn "Falha ao baixar $f"
            }
        done

        if [[ -d "$gui_src/locale" ]]; then
            cp "$gui_src"/locale/*.json "$LOCAL_GUI_DIR/locale/" 2>/dev/null || true
        fi

        if [[ -f "$LOCAL_GUI_DIR/execute_demo" ]]; then
            chmod +x "$LOCAL_GUI_DIR/execute_demo" "$LOCAL_GUI_DIR/biglinuxcleaner-gui.sh" "$LOCAL_GUI_DIR/run_cleanup.sh" 2>/dev/null || true
            log_ok "GUI baixada via GitHub."
            return 0
        fi
    fi

    log_warn "Não foi possível instalar a GUI. Apenas o CLI estará disponível."
    return 1
}

install_shortcut() {
    local install_menu="$1" install_desktop="$2"

    install_cleaner_local || return 1
    install_icon || return 1
    install_gui || true

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
    # Tenta refresh específico do DE se lib estiver disponível
    if [[ -f "$LIB_DIR/refresh_de.sh" ]]; then
        source "$LIB_DIR/refresh_de.sh"
        refresh_desktop_environment >/dev/null 2>&1 || true
    else
        # Fallback KDE
        if command -v kbuildsycoca6 >/dev/null 2>&1; then
            kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
        elif command -v kbuildsycoca5 >/dev/null 2>&1; then
            kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
        fi
    fi
}

uninstall() {
    local desktop_dir removed=0 size dir
    desktop_dir="$(get_desktop_dir)"

    for f in "$MENU_DIR/$DESKTOP_ID" "$desktop_dir/$DESKTOP_ID" \
             "$MENU_DIR/biglinuxcleaner-gui.desktop" "$desktop_dir/biglinuxcleaner-gui.desktop"; do
        if [[ -f "$f" ]]; then
            rm -f "$f" && ((removed += 1))
        fi
    done

    for size in "${ICON_SIZES[@]}"; do
        dir="$HICOLOR_DIR/${size}x${size}/apps"
        if [[ -f "$dir/$ICON_NAME.png" ]]; then
            rm -f "$dir/$ICON_NAME.png" && ((removed += 1))
        fi
    done

    if [[ -f "$SVG_ICON_DIR/$ICON_NAME.svg" ]]; then
        rm -f "$SVG_ICON_DIR/$ICON_NAME.svg" && ((removed += 1))
    fi

    if [[ -d "$LOCAL_INSTALL_DIR" ]]; then
        rm -rf "$LOCAL_INSTALL_DIR" && ((removed += 1))
        log_info "Script local removido de $LOCAL_INSTALL_DIR"
    fi

    refresh_menu
    refresh_icon_cache

    if ((removed > 0)); then
        log_ok "Atalho, ícone, GUI e script do BigLinuxCleaner removidos."
    else
        log_warn "Nada para remover — o BigLinuxCleaner não estava instalado."
    fi
}

# ─── Pergunta local de instalação (interativo) ───
ask_install_location() {
    local choice
    echo >&2
    echo >&2 "Onde deseja instalar o atalho do BigLinuxCleaner?"
    echo >&2 "  1) Área de trabalho"
    echo >&2 "  2) Menu de aplicativos"
    echo >&2 "  3) Ambos (padrão)"
    echo >&2

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

# ─── Parse de argumentos não-interativos ───
parse_args() {
    INSTALL_MENU=0
    INSTALL_DESKTOP=0
    CHOSEN_TERMINAL=""
    AUTO_YES=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --uninstall|-u)
                uninstall
                exit 0
                ;;
            --menu)
                INSTALL_MENU=1
                ;;
            --desktop)
                INSTALL_DESKTOP=1
                ;;
            --terminal=*)
                CHOSEN_TERMINAL="${1#--terminal=}"
                export CHOSEN_TERMINAL
                ;;
            --yes|-y)
                AUTO_YES=1
                ;;
            --help|-h)
                cat <<EOF
Uso: $0 [opções]

Opções:
  --uninstall, -u        Remove atalho, ícone, GUI e script local
  --menu                 Instala apenas no menu de aplicativos
  --desktop              Instala apenas na área de trabalho
  --terminal=CMD         Define terminal a usar (ex: konsole, gnome-terminal)
  --yes, -y              Modo não-interativo (usa padrões)
  --help, -h             Mostra esta ajuda

Sem opções: modo interativo (pergunta local + terminal)
Instala CLI + GUI (BigBashView) quando disponível.
EOF
                exit 0
                ;;
            *)
                log_err "Opção desconhecida: $1"
                exit 1
                ;;
        esac
        shift
    done

    # Se nem --menu nem --desktop, instala em ambos por padrão
    if [[ $INSTALL_MENU -eq 0 && $INSTALL_DESKTOP -eq 0 ]]; then
        INSTALL_MENU=1
        INSTALL_DESKTOP=1
    fi
}

# ─── Main ───
main() {
    parse_args "$@"

    if ! command -v curl >/dev/null 2>&1; then
        log_warn "'curl' não encontrado — o atalho não conseguirá executar o cleaner."
    fi

    log_info "Instalando o BigLinuxCleaner como atalho no sistema..."

    # Modo interativo: pergunta local e terminal
    if [[ $AUTO_YES -eq 0 && -z "$CHOSEN_TERMINAL" ]]; then
        local loc menu desktop
        loc="$(ask_install_location)" || exit 1
        read -r menu desktop <<<"$loc"
        INSTALL_MENU=$menu
        INSTALL_DESKTOP=$desktop

        # Pergunta terminal interativamente
        if ! choose_terminal_interactive; then
            log_err "Nenhum terminal selecionado. Instalação cancelada."
            exit 1
        fi
    elif [[ -z "$CHOSEN_TERMINAL" ]]; then
        # Modo não-interativo sem --terminal: usa preferido do DE
        if [[ -f "$LIB_DIR/detect_de.sh" ]]; then
            source "$LIB_DIR/detect_de.sh"
            detect_desktop_environment
        fi
        if [[ -f "$LIB_DIR/terminals.sh" ]]; then
            source "$LIB_DIR/terminals.sh"
            detect_available_terminals
            CHOSEN_TERMINAL="$(get_preferred_terminal_for_de)"
            export CHOSEN_TERMINAL
        fi
    fi

    install_shortcut "$INSTALL_MENU" "$INSTALL_DESKTOP" || exit 1
    refresh_menu

    echo
    log_ok "Instalação concluída!"
    if [[ -n "${CHOSEN_TERMINAL:-}" ]]; then
        if [[ "$CHOSEN_TERMINAL" == "xdg-terminal-exec" ]]; then
            log_info "O atalho abre no seu terminal padrão (resolvido automaticamente via xdg-terminal-exec)."
        else
            log_info "O atalho abre no terminal: $CHOSEN_TERMINAL"
        fi
    else
        log_warn "Nenhum terminal detectado — o atalho usará o terminal do ambiente."
    fi
    log_info "Para remover depois, execute: $0 --uninstall"
}

main "$@"