#!/bin/bash
#
# lib/terminals.sh — Detecção e listagem de terminais disponíveis
# Parte do BigLinuxCleaner — Instalador interativo multi-DE
#
# Uso:
#   source /path/to/lib/terminals.sh
#   detect_available_terminals
#   choose_terminal_interactive
#   echo "Terminal escolhido: $CHOSEN_TERMINAL"

# Lista de terminais conhecidos (ordem de preferência por DE)
# Formato: "comando|nome_amigavel|de_associado"
KNOWN_TERMINALS=(
    # KDE Plasma
    "konsole|Konsole|kde"
    "kitty|Kitty|kde"
    "yakuake|Yakuake|kde"

    # GNOME
    "gnome-terminal|GNOME Terminal|gnome"
    "kgx|GNOME Console|gnome"
    "tilix|Tilix|gnome"

    # XFCE
    "xfce4-terminal|XFCE Terminal|xfce"

    # Cinnamon
    "gnome-terminal|GNOME Terminal|cinnamon"
    "kgx|GNOME Console|cinnamon"

    # Genéricos / Populares
    "alacritty|Alacritty|"
    "ghostty|Ghostty|"
    "wezterm|WezTerm|"
    "foot|Foot|"
    "kitty|Kitty|"
    "terminator|Terminator|"
    "urxvt|rxvt-unicode|"
    "xterm|XTerm|"
)

# Terminais preferidos por DE (para sugestão automática)
PREFERRED_TERMINAL_BY_DE=(
    "kde:konsole"
    "gnome:gnome-terminal"
    "xfce:xfce4-terminal"
    "cinnamon:gnome-terminal"
)

# Array global para terminais detectados
DETECTED_TERMINALS=()
DETECTED_TERMINAL_NAMES=()
DETECTED_TERMINAL_DES=()

# Detecta terminais disponíveis no sistema
detect_available_terminals() {
    DETECTED_TERMINALS=()
    DETECTED_TERMINAL_NAMES=()
    DETECTED_TERMINAL_DES=()

    local entry cmd name de
    for entry in "${KNOWN_TERMINALS[@]}"; do
        IFS='|' read -r cmd name de <<<"$entry"
        if command -v "$cmd" >/dev/null 2>&1; then
            DETECTED_TERMINALS+=("$cmd")
            DETECTED_TERMINAL_NAMES+=("$name")
            DETECTED_TERMINAL_DES+=("$de")
        fi
    done

    # Adiciona xdg-terminal-exec se disponível (padrão freedesktop)
    if command -v xdg-terminal-exec >/dev/null 2>&1; then
        # Insere no início como opção "Sistema (padrão)"
        DETECTED_TERMINALS=("xdg-terminal-exec" "${DETECTED_TERMINALS[@]}")
        DETECTED_TERMINAL_NAMES=("Sistema (padrão freedesktop)" "${DETECTED_TERMINAL_NAMES[@]}")
        DETECTED_TERMINAL_DES=("" "${DETECTED_TERMINAL_DES[@]}")
    fi

    # Adiciona terminal atual como fallback
    local current_term=""
    if [[ -n "${TERMINAL:-}" ]]; then
        current_term="${TERMINAL%% *}"
        current_term="${current_term##*/}"
    elif [[ -n "${TERM_PROGRAM:-}" ]]; then
        current_term="${TERM_PROGRAM,,}"
    fi

    if [[ -n "$current_term" ]] && command -v "$current_term" >/dev/null 2>&1; then
        local found=0
        for cmd in "${DETECTED_TERMINALS[@]}"; do
            [[ "$cmd" == "$current_term" ]] && found=1 && break
        done
        if [[ $found -eq 0 ]]; then
            DETECTED_TERMINALS+=("$current_term")
            DETECTED_TERMINAL_NAMES+=("$current_term (terminal atual)")
            DETECTED_TERMINAL_DES+=("")
        fi
    fi
}

# Retorna terminal preferido para o DE atual
get_preferred_terminal_for_de() {
    local de="${1:-${DESKTOP_ENVIRONMENT:-}}"
    local pref

    for pref in "${PREFERRED_TERMINAL_BY_DE[@]}"; do
        IFS=':' read -r pref_de pref_term <<<"$pref"
        if [[ "$pref_de" == "$de" ]]; then
            # Verifica se está instalado
            if command -v "$pref_term" >/dev/null 2>&1; then
                printf '%s\n' "$pref_term"
                return 0
            fi
        fi
    done

    # Fallback: primeiro terminal detectado
    if [[ ${#DETECTED_TERMINALS[@]} -gt 0 ]]; then
        printf '%s\n' "${DETECTED_TERMINALS[0]}"
        return 0
    fi

    return 1
}

# Interface interativa para escolher terminal
choose_terminal_interactive() {
    detect_available_terminals

    if [[ ${#DETECTED_TERMINALS[@]} -eq 0 ]]; then
        log_err "Nenhum terminal encontrado no sistema!"
        return 1
    fi

    echo
    echo -e "\033[1;34m╔══════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m║         Escolha o terminal para o atalho do BigLinuxCleaner ║\033[0m"
    echo -e "\033[1;34m╚══════════════════════════════════════════════════════════╝\033[0m"
    echo

    local i=1
    local cmd name de
    for i in "${!DETECTED_TERMINALS[@]}"; do
        cmd="${DETECTED_TERMINALS[i]}"
        name="${DETECTED_TERMINAL_NAMES[i]}"
        de="${DETECTED_TERMINAL_DES[i]}"

        local marker=""
        if [[ $i -eq 0 ]]; then
            marker=" \033[0;32m← Recomendado\033[0m"
        elif [[ -n "$de" && "$de" == "${DESKTOP_ENVIRONMENT:-}" ]]; then
            marker=" \033[0;36m← Nativo do $DESKTOP_ENVIRONMENT_PRETTY\033[0m"
        fi

        printf "  \033[1;33m%2d\033[0m) %s%s\n" $((i+1)) "$name" "$marker"
    done

    echo
    echo -e "  \033[1;33m 0\033[0m) Cancelar instalação"
    echo

    local choice
    while true; do
        read -rp "$(echo -e '\033[1;36mEscolha [1-'${#DETECTED_TERMINALS[@]}'] ou 0 para cancelar:\033[0m ')" choice

        if [[ "$choice" == "0" ]]; then
            echo "Instalação cancelada."
            return 1
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DETECTED_TERMINALS[@]} )); then
            local idx=$((choice - 1))
            CHOSEN_TERMINAL="${DETECTED_TERMINALS[idx]}"
            CHOSEN_TERMINAL_NAME="${DETECTED_TERMINAL_NAMES[idx]}"
            export CHOSEN_TERMINAL
            export CHOSEN_TERMINAL_NAME
            log_ok "Terminal selecionado: $CHOSEN_TERMINAL_NAME ($CHOSEN_TERMINAL)"
            return 0
        fi

        echo -e "\033[0;31mOpção inválida. Tente novamente.\033[0m"
    done
}

# Gera linha Exec= para arquivo .desktop
generate_desktop_exec_line() {
    local terminal="${1:-$CHOSEN_TERMINAL}"
    local script_path="${2:-$HOME/.local/share/BigLinuxCleaner/cleaner.sh}"

    case "$terminal" in
        xdg-terminal-exec)
            # Padrão freedesktop - resolve no momento do clique
            printf 'Exec=xdg-terminal-exec -- bash -c "%s; read -p \"Pressione Enter para fechar...\" "\n' "$script_path"
            ;;
        konsole)
            printf 'Exec=konsole --hold -e bash -c "%s"\n' "$script_path"
            ;;
        gnome-terminal|kgx)
            printf 'Exec=%s -- bash -c "%s; read -p \"Pressione Enter para fechar...\" "\n' "$terminal" "$script_path"
            ;;
        xfce4-terminal)
            printf 'Exec=xfce4-terminal --hold -e "bash -c \"%s\""\n' "$script_path"
            ;;
        alacritty|ghostty|wezterm|foot|kitty)
            printf 'Exec=%s --hold -e bash -c "%s"\n' "$terminal" "$script_path"
            ;;
        terminator)
            printf 'Exec=terminator --hold -e "bash -c \"%s\""\n' "$script_path"
            ;;
        urxvt|rxvt-unicode)
            printf 'Exec=urxvt -hold -e bash -c "%s"\n' "$script_path"
            ;;
        xterm)
            printf 'Exec=xterm -hold -e bash -c "%s"\n' "$script_path"
            ;;
        *)
            # Fallback genérico
            printf 'Exec=%s -e bash -c "%s; read -p \"Pressione Enter para fechar...\" "\n' "$terminal" "$script_path"
            ;;
    esac
}

# Se executado diretamente, testa a detecção
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    if ! declare -f log_info >/dev/null 2>&1; then
        log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
        log_ok()   { echo -e "\033[0;32m[OK]\033[0m $*"; }
        log_err()  { echo -e "\033[0;31m[ERRO]\033[0m $*"; }
    fi

    # Carrega detecção de DE se disponível
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/detect_de.sh" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/detect_de.sh"
        detect_desktop_environment
    fi

    detect_available_terminals
    echo "Terminais detectados: ${#DETECTED_TERMINALS[@]}"
    for i in "${!DETECTED_TERMINALS[@]}"; do
        echo "  $((i+1)). ${DETECTED_TERMINAL_NAMES[i]} (${DETECTED_TERMINALS[i]}) ${DETECTED_TERMINAL_DES[i]:+[DE: ${DETECTED_TERMINAL_DES[i]}]}"
    done

    preferred=$(get_preferred_terminal_for_de)
    echo "Preferido para ${DESKTOP_ENVIRONMENT_PRETTY:-$DESKTOP_ENVIRONMENT}: $preferred"
fi