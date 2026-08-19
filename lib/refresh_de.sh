#!/bin/bash
#
# lib/refresh_de.sh — Refresh universal de menu/cache por Desktop Environment
# Parte do BigLinuxCleaner — Compatível com BigCommunity (KDE, GNOME, XFCE, Cinnamon)
#
# Uso:
#   source /path/to/lib/refresh_de.sh
#   refresh_desktop_environment
#
# Requer: lib/detect_de.sh (para DESKTOP_ENVIRONMENT)

# Atualiza banco de dados de aplicações (freedesktop padrão)
update_desktop_database() {
    local dirs=(
        "$HOME/.local/share/applications"
        "/usr/share/applications"
        "/usr/local/share/applications"
    )
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] && update-desktop-database "$dir" >/dev/null 2>&1 || true
    done
}

# Atualiza cache de ícones GTK (hicolor theme)
update_icon_cache() {
    local dirs=(
        "$HOME/.local/share/icons/hicolor"
        "/usr/share/icons/hicolor"
    )
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] && gtk-update-icon-cache -f -t "$dir" >/dev/null 2>&1 || true
    done
}

# Refresh específico para KDE Plasma
refresh_kde() {
    log_info "Atualizando KDE Plasma..."

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1
    elif command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 --noincremental >/dev/null 2>&1
    else
        log_warn "kbuildsycoca não encontrado."
    fi

    rm -f "$HOME/.local/share/krunnerstaterc" 2>/dev/null || true
    rm -rf "$HOME/.cache/krunner"/* 2>/dev/null || true
    rm -rf "$HOME/.cache/plasmashell"* 2>/dev/null || true
    rm -f "$HOME/.cache/org.kde.dirmodel-cache.kcache" 2>/dev/null || true

    if pgrep -x krunner >/dev/null 2>&1; then
        if command -v kquitapp6 >/dev/null 2>&1; then
            kquitapp6 krunner 2>/dev/null || true
            sleep 1
            kstart6 --nosplash krunner 2>/dev/null &
        elif command -v kquitapp5 >/dev/null 2>&1; then
            kquitapp5 krunner 2>/dev/null || true
            sleep 1
            kstart5 --nosplash krunner 2>/dev/null &
        else
            killall -SIGTERM krunner 2>/dev/null || true
            nohup krunner >/dev/null 2>&1 &
        fi
    fi

    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file krunnerrc --group General --key PastQueries "[]" >/dev/null 2>&1 || true
    elif command -v kwriteconfig5 >/dev/null 2>&1; then
        kwriteconfig5 --file krunnerrc --group General --key PastQueries "[]" >/dev/null 2>&1 || true
    fi

    log_ok "KDE Plasma atualizado."
}

# Refresh específico para GNOME
refresh_gnome() {
    log_info "Atualizando GNOME..."

    update_desktop_database
    update_icon_cache

    # GNOME Shell: reinicia se estiver rodando (Wayland/X11)
    if pgrep -x gnome-shell >/dev/null 2>&1; then
        # No Wayland, gnome-shell reinicia sozinho com sinal
        # No X11, pode precisar de reinício manual
        killall -SIGQUIT gnome-shell 2>/dev/null || true
        # Pequena pausa para reinício
        sleep 1
    fi

    # Limpa cache do dconf (opcional, pode ser lento)
    # dconf reset -f /org/gnome/shell/ 2>/dev/null || true

    log_ok "GNOME atualizado."
}

# Refresh específico para XFCE
refresh_xfce() {
    log_info "Atualizando XFCE..."

    update_desktop_database
    update_icon_cache

    # Reinicia painel do XFCE
    if command -v xfce4-panel >/dev/null 2>&1; then
        xfce4-panel -r >/dev/null 2>&1 || true
    fi

    # Reinicia xfdesktop (gerencia ícones da área de trabalho)
    if pgrep -x xfdesktop >/dev/null 2>&1; then
        killall xfdesktop 2>/dev/null || true
        nohup xfdesktop >/dev/null 2>&1 &
    fi

    log_ok "XFCE atualizado."
}

# Refresh específico para Cinnamon
refresh_cinnamon() {
    log_info "Atualizando Cinnamon..."

    update_desktop_database
    update_icon_cache

    # Reinicia cinnamon-settings-daemon
    if pgrep -x cinnamon-settings-daemon >/dev/null 2>&1; then
        killall cinnamon-settings-daemon 2>/dev/null || true
        nohup cinnamon-settings-daemon >/dev/null 2>&1 &
    fi

    # Reinicia Cinnamon (processo principal)
    if pgrep -x cinnamon >/dev/null 2>&1; then
        # Cinnamon reinicia sozinho com SIGQUIT
        killall -SIGQUIT cinnamon 2>/dev/null || true
        sleep 1
    fi

    log_ok "Cinnamon atualizado."
}

# Refresh genérico (fallback para DEs não suportados)
refresh_generic() {
    log_info "Atualizando ambiente genérico (freedesktop)..."

    update_desktop_database
    update_icon_cache

    log_ok "Ambiente genérico atualizado."
}

# Função principal: detecta DE e executa refresh apropriado
refresh_desktop_environment() {
    # Garante que a detecção foi feita
    if [[ -z "${DESKTOP_ENVIRONMENT:-}" ]]; then
        source "$(dirname "${BASH_SOURCE[0]:-}")/detect_de.sh"
        detect_desktop_environment
    fi

    local de="${DESKTOP_ENVIRONMENT:-unknown}"

    log_info "Desktop Environment detectado: ${DESKTOP_ENVIRONMENT_PRETTY:-$de}"

    case "$de" in
        kde)       refresh_kde ;;
        gnome)     refresh_gnome ;;
        xfce)      refresh_xfce ;;
        cinnamon)  refresh_cinnamon ;;
        *)         refresh_generic ;;
    esac
}

# Se executado diretamente, roda o refresh
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    # Carrega funções de log se não existirem
    if ! declare -f log_info >/dev/null 2>&1; then
        log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
        log_ok()   { echo -e "\033[0;32m[OK]\033[0m $*"; }
        log_warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
    fi

    source "$(dirname "${BASH_SOURCE[0]:-}")/detect_de.sh"
    refresh_desktop_environment
fi