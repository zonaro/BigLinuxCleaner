#!/bin/bash
#
# install.sh — Instala o BigLinuxCleaner como atalho (.desktop) no sistema.
#
# Instala uma cópia local do cleaner.sh em ~/.local/share/BigLinuxCleaner/
# e cria um atalho (Área de trabalho e/ou Menu de aplicativos) que executa
# o script local. Se online, o cleaner tenta se auto-atualizar a cada
# execução. Se offline, roda a versão em cache sem tentar baixar ícones
# da Steam. Também instala o ícone oficial em PNG (256/128/64 px).
#
# Uso:
#   ./install.sh              Instala (pergunta onde criar o atalho)
#   ./install.sh --uninstall  Remove o atalho, ícone e script local
#
# Também pode ser executado direto do GitHub:
#   curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/install.sh | bash

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

# Descobre o terminal padrão do usuário. Não depende de nenhum terminal
# específico — usa, nesta ordem: xdg-terminal-exec (padrão freedesktop, que
# resolve o terminal no momento do clique), config do KDE, $TERMINAL,
# x-terminal-emulator e uma lista de terminais comuns.
detect_terminal() {
    local term=""

    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        term="xdg-terminal-exec"
    elif command -v kreadconfig6 >/dev/null 2>&1; then
        term="$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication 2>/dev/null || true)"
    elif command -v kreadconfig5 >/dev/null 2>&1; then
        term="$(kreadconfig5 --file kdeglobals --group General --key TerminalApplication 2>/dev/null || true)"
    fi
    [[ -z "$term" ]] && term="${TERMINAL:-}"

    if [[ -z "$term" ]] && command -v x-terminal-emulator >/dev/null 2>&1; then
        term="x-terminal-emulator"
    fi
    if [[ -z "$term" ]]; then
        for t in konsole gnome-terminal kitty alacritty ghostty xfce4-terminal tilix terminator wezterm deepin-terminal urxvt xterm; do
            if command -v "$t" >/dev/null 2>&1; then
                term="$t"
                break
            fi
        done
    fi

    # Normaliza ids como "org.kde.konsole.desktop"/"org.kde.konsole" → "konsole"
    # e remove field codes do KDE + espaços (ex.: "ashyterm %F" → "ashyterm").
    term="${term%.desktop}"
    term="${term##*.}"
    term="$(printf '%s' "$term" | sed -E 's/%[A-Za-z]//g' | tr -d '[:space:]')"
    printf '%s' "$term"
}

# Flags do terminal para executar um comando (ex.: "-e bash -c", "-- bash -c").
terminal_run_args() {
    case "$1" in
        *wezterm*)           printf '%s' "start -- bash -c" ;;
        *gnome-terminal*)    printf '%s' "-- bash -c" ;;
        *kitty*)             printf '%s' "bash -c" ;;
        *xdg-terminal-exec*) printf '%s' "bash -c" ;;
        *)                   printf '%s' "-e bash -c" ;;
    esac
}

# Gera o conteúdo do arquivo .desktop. O Exec abre o terminal padrão do usuário
# e roda o cleaner direto do GitHub dentro dele.
build_desktop_content() {
    local term term_args desktop_term

    term="$(detect_terminal)"
    if [[ -n "$term" ]]; then
        term_args="$(terminal_run_args "$term")"
        desktop_term="Terminal=false"
    else
        # Sem terminal detectado: usa o comportamento antigo (Terminal=true + sh -c).
        term="sh"
        term_args="-c"
        desktop_term="Terminal=true"
    fi

    cat <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=BigLinuxCleaner
GenericName=Limpeza do sistema
Comment=Limpa atalhos quebrados, órfãos do pacman/flatpak/snap e o cache do KDE Plasma
Exec=${term} ${term_args} "bash ${LOCAL_CLEANER}; echo; read -rp \"Pressione Enter para fechar...\""
Icon=${ICON_NAME}
${desktop_term}
Categories=System;
Keywords=cleaner;limpeza;pacman;flatpak;snap;kde;atalhos;
StartupNotify=false
EOF
}

# Garante que o tema "hicolor" tenha index.theme (necessário para o KDE/GTK
# encontrarem ícones instalados pelo usuário).
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

# Atualiza o cache de ícones do tema hicolor (usado por GTK/gerenciadores de
# arquivos e alguns ambientes).
refresh_icon_cache() {
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$HICOLOR_DIR" >/dev/null 2>&1 || true
    fi
}

# Instala o ícone em PNG nos tamanhos oficiais do hicolor.
install_icon() {
    local size dir url

    ensure_hicolor_theme

    # Remove ícone SVG de instalações antigas (PNG tem prioridade e evita
    # conflito com o renderizador QtSvg do KDE).
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

# Instala o cleaner.sh localmente para funcionamento offline
install_cleaner_local() {
    log_info "Instalando script local do BigLinuxCleaner..."
    mkdir -p "$LOCAL_INSTALL_DIR"

    # Tenta baixar a versão mais recente
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --max-time 10 "$CLEANER_URL" -o "$LOCAL_CLEANER.tmp" 2>/dev/null; then
            if head -n 1 "$LOCAL_CLEANER.tmp" | grep -q '^#!/bin/bash'; then
                mv "$LOCAL_CLEANER.tmp" "$LOCAL_CLEANER"
                chmod +x "$LOCAL_CLEANER"
                log_ok "Script atualizado via GitHub."
                return 0
            fi
            rm -f "$LOCAL_CLEANER.tmp"
        fi
    fi

    # Fallback: copia o script local se existir (caso offline)
    if [[ -f "./cleaner.sh" ]]; then
        cp "./cleaner.sh" "$LOCAL_CLEANER"
        chmod +x "$LOCAL_CLEANER"
        log_ok "Script instalado localmente (cópia do diretório atual)."
    elif [[ -f "$LOCAL_CLEANER" ]]; then
        log_warn "Mantendo versão local existente (sem conexão)."
    else
        log_err "Não foi possível instalar o script. Execute no diretório do repositório."
        return 1
    fi
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

    install_cleaner_local || return 1
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
    local desktop_dir removed=0 size dir
    desktop_dir="$(get_desktop_dir)"

    for f in "$MENU_DIR/$DESKTOP_ID" "$desktop_dir/$DESKTOP_ID"; do
        if [[ -f "$f" ]]; then
            rm -f "$f" && ((removed += 1))
        fi
    done

    # Ícones em PNG (instalações atuais)
    for size in "${ICON_SIZES[@]}"; do
        dir="$HICOLOR_DIR/${size}x${size}/apps"
        if [[ -f "$dir/$ICON_NAME.png" ]]; then
            rm -f "$dir/$ICON_NAME.png" && ((removed += 1))
        fi
    done

    # Ícone em SVG (instalações antigas)
    if [[ -f "$SVG_ICON_DIR/$ICON_NAME.svg" ]]; then
        rm -f "$SVG_ICON_DIR/$ICON_NAME.svg" && ((removed += 1))
    fi

    # Remove o script local
    if [[ -d "$LOCAL_INSTALL_DIR" ]]; then
        rm -rf "$LOCAL_INSTALL_DIR" && ((removed += 1))
        log_info "Script local removido de $LOCAL_INSTALL_DIR"
    fi

    refresh_menu
    refresh_icon_cache

    if ((removed > 0)); then
        log_ok "Atalho, ícone e script do BigLinuxCleaner removidos."
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

    local term
    term="$(detect_terminal)"
    echo
    log_ok "Instalação concluída!"
    if [[ "$term" == "xdg-terminal-exec" ]]; then
        log_info "O atalho abre no seu terminal padrão (resolvido automaticamente)."
    elif [[ -n "$term" ]]; then
        log_info "O atalho abre no terminal padrão ($term) e roda o cleaner do GitHub."
    else
        log_warn "Nenhum terminal detectado — o atalho usará o terminal do ambiente."
    fi
    log_info "Para remover depois, execute: ./install.sh --uninstall"
}

main "$@"
