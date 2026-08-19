#!/bin/bash
#
# lib/detect_de.sh — Detecção de Desktop Environment
# Parte do BigLinuxCleaner — Compatível com BigCommunity (KDE, GNOME, XFCE, Cinnamon)
#
# Uso:
#   source /path/to/lib/detect_de.sh
#   detect_desktop_environment
#   echo "DE detectado: $DESKTOP_ENVIRONMENT"
#   echo "DE pretty: $DESKTOP_ENVIRONMENT_PRETTY"

# Retorna o DE detectado via stdout e define variáveis globais:
#   DESKTOP_ENVIRONMENT — ID canônico: kde, gnome, xfce, cinnamon, mate, lxqt, budgie, unknown
#   DESKTOP_ENVIRONMENT_PRETTY — Nome amigável para exibição

detect_desktop_environment() {
    local de_id=""
    local de_pretty=""

    # 1. Prioridade: XDG_CURRENT_DESKTOP (padrão freedesktop)
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        local xdg_de="${XDG_CURRENT_DESKTOP,,}"  # lowercase
        case "$xdg_de" in
            *kde*|*plasma*)     de_id="kde";     de_pretty="KDE Plasma" ;;
            *gnome*|*ubuntu*)   de_id="gnome";   de_pretty="GNOME" ;;
            *xfce*)             de_id="xfce";    de_pretty="XFCE" ;;
            *cinnamon*)         de_id="cinnamon"; de_pretty="Cinnamon" ;;
            *mate*)             de_id="mate";    de_pretty="MATE" ;;
            *lxqt*)             de_id="lxqt";    de_pretty="LXQt" ;;
            *budgie*)           de_id="budgie";  de_pretty="Budgie" ;;
            *deepin*)           de_id="deepin";  de_pretty="Deepin" ;;
            *enlightenment*)    de_id="enlightenment"; de_pretty="Enlightenment" ;;
        esac
    fi

    # 2. Fallback: DESKTOP_SESSION
    if [[ -z "$de_id" && -n "${DESKTOP_SESSION:-}" ]]; then
        local session="${DESKTOP_SESSION,,}"
        case "$session" in
            *kde*|*plasma*)     de_id="kde";     de_pretty="KDE Plasma" ;;
            *gnome*|*ubuntu*)   de_id="gnome";   de_pretty="GNOME" ;;
            *xfce*)             de_id="xfce";    de_pretty="XFCE" ;;
            *cinnamon*)         de_id="cinnamon"; de_pretty="Cinnamon" ;;
            *mate*)             de_id="mate";    de_pretty="MATE" ;;
            *lxqt*)             de_id="lxqt";    de_pretty="LXQt" ;;
            *budgie*)           de_id="budgie";  de_pretty="Budgie" ;;
        esac
    fi

    # 3. Fallback: Processos ativos (detecção por processo pai/filho)
    if [[ -z "$de_id" ]]; then
        if pgrep -x plasmashell >/dev/null 2>&1; then
            de_id="kde"; de_pretty="KDE Plasma"
        elif pgrep -x gnome-shell >/dev/null 2>&1; then
            de_id="gnome"; de_pretty="GNOME"
        elif pgrep -x xfce4-panel >/dev/null 2>&1; then
            de_id="xfce"; de_pretty="XFCE"
        elif pgrep -x cinnamon >/dev/null 2>&1; then
            de_id="cinnamon"; de_pretty="Cinnamon"
        elif pgrep -x mate-panel >/dev/null 2>&1; then
            de_id="mate"; de_pretty="MATE"
        elif pgrep -x lxqt-panel >/dev/null 2>&1; then
            de_id="lxqt"; de_pretty="LXQt"
        elif pgrep -x budgie-panel >/dev/null 2>&1; then
            de_id="budgie"; de_pretty="Budgie"
        fi
    fi

    # 4. Fallback final
    if [[ -z "$de_id" ]]; then
        de_id="unknown"
        de_pretty="Desconhecido"
    fi

    # Exporta para uso global
    export DESKTOP_ENVIRONMENT="$de_id"
    export DESKTOP_ENVIRONMENT_PRETTY="$de_pretty"

    # Retorna via stdout para captura
    printf '%s\n' "$de_id"
}

# Verifica se estamos rodando em um DE suportado pelo BigCommunity
is_bigcommunity_de() {
    local de="${1:-$DESKTOP_ENVIRONMENT}"
    case "$de" in
        kde|gnome|xfce|cinnamon) return 0 ;;
        *) return 1 ;;
    esac
}

# Retorna lista de DEs suportados
get_supported_des() {
    printf 'kde\ngnome\nxfce\ncinnamon\n'
}

# Se executado diretamente (não sourced), roda a detecção e imprime
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    detect_desktop_environment
    echo "DE: $DESKTOP_ENVIRONMENT ($DESKTOP_ENVIRONMENT_PRETTY)"
    if is_bigcommunity_de; then
        echo "✅ DE suportado pelo BigCommunity"
    else
        echo "⚠️  DE não oficialmente suportado (funcionalidade limitada)"
    fi
fi