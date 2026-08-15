#!/bin/bash

# curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/cleaner.sh | bash

set -Eeuo pipefail

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretórios para verificar (Sistema, Usuário, Flatpak e Snap)
DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
    "/var/lib/flatpak/exports/share/applications"
    "/var/lib/snapd/desktop/applications"
)

SCANNED=0
INVALID=0
REMOVED=0
FAILED=0
STEAM_FIXED=0

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERRO]${NC} $*"; }

trap 'log_err "Falha na linha ${LINENO}. Abortando."' ERR

need_sudo() {
    local d
    for d in "${DIRS[@]}"; do
        if [[ "$d" == /usr/* || "$d" == /var/* ]]; then
            return 0
        fi
    done
    return 1
}

prepare_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        return
    fi
    if need_sudo; then
        log_info "Preparando permissões elevadas (sudo)..."
        sudo -v
    fi
}

cleanup_orphans() {
    if ! command -v pacman >/dev/null 2>&1; then
        log_warn "pacman não encontrado; limpeza de órfãos ignorada."
        return
    fi

    log_info "Limpando pacotes órfãos..."
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)

    if ((${#orphans[@]} == 0)); then
        log_ok "Nenhum pacote órfão encontrado."
        return
    fi

    sudo pacman -Rns --noconfirm "${orphans[@]}"
    log_ok "Pacotes órfãos removidos: ${#orphans[@]}"
}

teste_and_remove_flatpak() {
    local file app_name app_id
    local -A installed_apps=()

    if ! command -v flatpak >/dev/null 2>&1; then
        log_warn "flatpak não encontrado; validação de atalhos do Flatpak ignorada."
        return
    fi

    while IFS= read -r app_id; do
        [[ -n "$app_id" ]] && installed_apps["$app_id"]=1
    done < <(flatpak list --app --columns=application 2>/dev/null || true)

    log_info "Verificando atalhos órfãos do Flatpak por app ID..."
    while IFS= read -r -d '' file; do
        ((SCANNED += 1))
        app_name="$(grep -m 1 '^Name=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
        app_id="$(basename "$file" .desktop)"

        if [[ -z "${installed_apps[$app_id]+x}" ]]; then
            ((INVALID += 1))
            log_warn "Atalho órfão do Flatpak detectado"
            echo -e "  App: ${YELLOW}${app_name:-Sem Nome}${NC}"
            echo -e "  Arquivo: $file"
            echo -e "  Flatpak ID: ${app_id:-desconhecido}"

            if remove_desktop_file "$file"; then
                ((REMOVED += 1))
                log_ok "Atalho removido (pacote Flatpak inexistente)."
            else
                ((FAILED += 1))
                log_err "Falha ao remover arquivo (permissão insuficiente)."
            fi
        fi
    done < <(
        find "$HOME/.local/share/flatpak/exports/share/applications" \
             "/var/lib/flatpak/exports/share/applications" \
             -type f -name '*.desktop' -print0 2>/dev/null
    )
}

extract_snap_name_from_desktop() {
    local file="$1"
    local snap_name base

    snap_name="$(grep -m 1 '^X-SnapInstanceName=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
    if [[ -n "$snap_name" ]]; then
        echo "$snap_name"
        return
    fi

    base="$(basename "$file" .desktop)"

    if [[ "$base" == snap.*.* ]]; then
        snap_name="${base#snap.}"
        snap_name="${snap_name%%.*}"
        echo "$snap_name"
        return
    fi

    if [[ "$base" == *_* ]]; then
        echo "${base%%_*}"
        return
    fi

    echo "$base"
}

teste_and_remove_snap() {
    local file app_name snap_name
    local -A installed_snaps=()

    if ! command -v snap >/dev/null 2>&1; then
        log_warn "snap não encontrado; validação de atalhos do Snap ignorada."
        return
    fi

    while IFS= read -r snap_name; do
        [[ -n "$snap_name" ]] && installed_snaps["$snap_name"]=1
    done < <(snap list 2>/dev/null | awk 'NR>1{print $1}')

    log_info "Verificando atalhos órfãos do Snap por nome do pacote..."
    while IFS= read -r -d '' file; do
        ((SCANNED += 1))
        app_name="$(grep -m 1 '^Name=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
        snap_name="$(extract_snap_name_from_desktop "$file")"

        if [[ -z "${installed_snaps[$snap_name]+x}" ]]; then
            ((INVALID += 1))
            log_warn "Atalho órfão do Snap detectado"
            echo -e "  App: ${YELLOW}${app_name:-Sem Nome}${NC}"
            echo -e "  Arquivo: $file"
            echo -e "  Snap: ${snap_name:-desconhecido}"

            if remove_desktop_file "$file"; then
                ((REMOVED += 1))
                log_ok "Atalho removido (pacote Snap inexistente)."
            else
                ((FAILED += 1))
                log_err "Falha ao remover arquivo (permissão insuficiente)."
            fi
        fi
    done < <(find "/var/lib/snapd/desktop/applications" -type f -name '*.desktop' -print0 2>/dev/null)
}

cleanup_flatpak_snap_cache() {
    local snap_line snap_name snap_rev

    log_info "Limpando cache e resíduos do Flatpak/Snap..."

    if command -v flatpak >/dev/null 2>&1; then
        # Remove runtimes/pacotes sem uso que costumam ficar como resíduo.
        flatpak uninstall --unused -y >/dev/null 2>&1 || true

        # Limpa cache local do Flatpak do usuário.
        rm -rf "$HOME/.cache/flatpak"/* 2>/dev/null || true

        # Limpa cache global do Flatpak quando houver permissão.
        if command -v sudo >/dev/null 2>&1; then
            sudo rm -rf /var/tmp/flatpak-cache/* 2>/dev/null || true
        fi

        log_ok "Limpeza do Flatpak concluída."
    else
        log_warn "flatpak não encontrado; limpeza do Flatpak ignorada."
    fi

    if command -v snap >/dev/null 2>&1; then
        # Remove revisões desabilitadas para recuperar espaço.
        while IFS= read -r snap_line; do
            [[ -n "$snap_line" ]] || continue
            snap_name="$(awk '{print $1}' <<<"$snap_line")"
            snap_rev="$(awk '{print $2}' <<<"$snap_line")"

            if [[ -n "$snap_name" && -n "$snap_rev" ]]; then
                sudo snap remove "$snap_name" --revision="$snap_rev" >/dev/null 2>&1 || true
            fi
        done < <(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}')

        # Limpa arquivos .snap em cache local do daemon.
        if command -v sudo >/dev/null 2>&1; then
            sudo rm -f /var/lib/snapd/cache/*.snap 2>/dev/null || true
        fi

        log_ok "Limpeza do Snap concluída."
    else
        log_warn "snap não encontrado; limpeza do Snap ignorada."
    fi
}

extract_exec_bin() {
    local line="$1"
    local cmd

    cmd="${line#Exec=}"
    cmd="${cmd#${cmd%%[![:space:]]*}}"

    while [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+ ]]; do
        cmd="${cmd#${BASH_REMATCH[0]}}"
    done

    if [[ "$cmd" =~ ^\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    echo "${cmd%%[[:space:]]*}"
}

is_exec_valid() {
    local exec_bin="$1"
    if [[ -z "$exec_bin" ]]; then
        return 1
    fi

    if [[ "$exec_bin" == /* ]]; then
        [[ -x "$exec_bin" ]]
        return
    fi

    command -v "$exec_bin" >/dev/null 2>&1
}

remove_desktop_file() {
    local file="$1"

    if rm -f "$file" 2>/dev/null; then
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo chmod u+w "$file" 2>/dev/null || true
        sudo rm -f "$file"
        return
    fi

    return 1
}

# Verifica se o ícone de um .desktop é válido: arquivo existente ou nome de
# tema resolvível no hicolor. Retorna 0 (true) se válido, 1 caso contrário.
is_icon_valid() {
    local icon_value="$1"

    [[ -z "$icon_value" ]] && return 1

    # Caminho absoluto ou relativo — verifica se o arquivo existe.
    if [[ "$icon_value" == /* ]]; then
        [[ -f "$icon_value" ]] && return 0
    fi

    # Nome de tema (ex.: steam_icon_730) — verifica nos diretórios hicolor.
    local size
    for size in 256x256 128x128 64x64 48x48 32x32 16x16 scalable; do
        if [[ -f "$HOME/.local/share/icons/hicolor/$size/apps/$icon_value.png" ]] ||
           [[ -f "$HOME/.local/share/icons/hicolor/$size/apps/$icon_value.svg" ]] ||
           [[ -f "/usr/share/icons/hicolor/$size/apps/$icon_value.png" ]] ||
           [[ -f "/usr/share/icons/hicolor/$size/apps/$icon_value.svg" ]]; then
            return 0
        fi
    done

    return 1
}

# Corrige ícones de atalhos da Steam que apontam para arquivos inexistentes.
# Baixa o header.jpg do jogo a partir do game ID na URL steam://rungameid/{id}
# e salva como ícone local. Se o ImageMagick estiver disponível, converte para
# PNG 256x256 com fundo transparente para melhor compatibilidade.
fix_steam_shortcut_icons() {
    local dir file exec_line icon_line icon_value game_id
    local steam_icon_dir="$HOME/.local/share/icons/steam-games"
    local has_convert=0

    if command -v convert >/dev/null 2>&1; then
        has_convert=1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl não encontrado; correção de ícones da Steam ignorada."
        return
    fi

    log_info "--- Corrigindo ícones de atalhos da Steam ---"

    mkdir -p "$steam_icon_dir"

    for dir in "${DIRS[@]}"; do
        [[ -d "$dir" ]] || continue

        while IFS= read -r -d '' file; do
            exec_line="$(grep -m 1 '^Exec=' "$file" 2>/dev/null || true)"

            # Detecta atalhos da Steam via steam://rungameid/{id}.
            if [[ ! "$exec_line" =~ steam://rungameid/([0-9]+) ]]; then
                continue
            fi

            game_id="${BASH_REMATCH[1]}"

            # Verifica se o ícone atual já é válido.
            icon_line="$(grep -m 1 '^Icon=' "$file" 2>/dev/null || true)"
            icon_value="${icon_line#Icon=}"

            if is_icon_valid "$icon_value"; then
                continue
            fi

            log_warn "Ícone inválido detectado: $(basename "$file" .desktop)"
            echo -e "  Arquivo: $file"
            echo -e "  Game ID: ${YELLOW}${game_id}${NC}"
            echo -e "  Icon atual: ${icon_value:-vazio}"

            # Define o caminho final do ícone.
            local final_icon

            # Verifica se já baixamos anteriormente.
            if [[ -f "$steam_icon_dir/${game_id}.png" ]]; then
                final_icon="$steam_icon_dir/${game_id}.png"
            elif [[ -f "$steam_icon_dir/${game_id}.jpg" ]]; then
                final_icon="$steam_icon_dir/${game_id}.jpg"
            else
                # Baixa o header do jogo da CDN da Steam.
                local header_url="https://cdn.akamai.steamstatic.com/steam/apps/${game_id}/header.jpg"
                local tmp_header="$steam_icon_dir/${game_id}_tmp.jpg"

                log_info "Baixando ícone do jogo (Steam AppID: $game_id)..."
                if ! curl -fsSL --max-time 10 "$header_url" -o "$tmp_header" 2>/dev/null; then
                    # Tenta o fallback via Cloudflare.
                    header_url="https://cdn.cloudflare.steamstatic.com/steam/apps/${game_id}/header.jpg"
                    curl -fsSL --max-time 10 "$header_url" -o "$tmp_header" 2>/dev/null || true
                fi

                if [[ ! -s "$tmp_header" ]]; then
                    log_err "Falha ao baixar ícone do jogo $game_id — pulando."
                    rm -f "$tmp_header"
                    continue
                fi

                # Converte para PNG 256x256 se ImageMagick disponível, senão
                # mantém como JPG.
                if ((has_convert)); then
                    if convert "$tmp_header" \
                        -background none \
                        -gravity center \
                        -resize 256x256 \
                        -extent 256x256 \
                        "$steam_icon_dir/${game_id}.png" 2>/dev/null; then
                        final_icon="$steam_icon_dir/${game_id}.png"
                        rm -f "$tmp_header"
                    else
                        # Fallback: renomeia para .jpg
                        mv "$tmp_header" "$steam_icon_dir/${game_id}.jpg"
                        final_icon="$steam_icon_dir/${game_id}.jpg"
                    fi
                else
                    mv "$tmp_header" "$steam_icon_dir/${game_id}.jpg"
                    final_icon="$steam_icon_dir/${game_id}.jpg"
                fi
            fi

            if [[ -z "$final_icon" || ! -s "$final_icon" ]]; then
                log_err "Ícone do jogo $game_id não pôde ser obtido."
                continue
            fi

            # Atualiza o campo Icon= no arquivo .desktop.
            sed -i "s|^Icon=.*|Icon=${final_icon}|" "$file"
            ((STEAM_FIXED += 1))
            log_ok "Ícone corrigido: $(basename "$file" .desktop) → $final_icon"

        done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done

    if ((STEAM_FIXED > 0)); then
        log_ok "Total de ícones da Steam corrigidos: $STEAM_FIXED"
    else
        log_ok "Nenhum ícone da Steam precisou de correção."
    fi
}

scan_and_clean_desktop_entries() {
    local dir file app_name exec_line exec_bin

    log_info "--- Iniciando varredura de atalhos quebrados ---"

    for dir in "${DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        log_info "Verificando diretório: $dir"

        while IFS= read -r -d '' file; do
            ((SCANNED += 1))

            app_name="$(grep -m 1 '^Name=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
            exec_line="$(grep -m 1 '^Exec=' "$file" 2>/dev/null || true)"

            [[ -n "$exec_line" ]] || continue
            exec_bin="$(extract_exec_bin "$exec_line")"

            if ! is_exec_valid "$exec_bin"; then
                ((INVALID += 1))
                log_warn "Atalho inválido detectado"
                echo -e "  App: ${YELLOW}${app_name:-Sem Nome}${NC}"
                echo -e "  Arquivo: $file"
                echo -e "  Exec: ${exec_bin:-vazio}"

                if remove_desktop_file "$file"; then
                    ((REMOVED += 1))
                    log_ok "Removido com sucesso."
                else
                    ((FAILED += 1))
                    log_err "Falha ao remover arquivo (permissão insuficiente)."
                fi
            fi
        done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done
}

refresh_kde() {
    log_info "Atualizando cache e menu do KDE Plasma..."

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    fi

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1
    elif command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 --noincremental >/dev/null 2>&1
    else
        log_warn "kbuildsycoca não encontrado; atualização de serviços do KDE ignorada."
    fi

    killall krunner 2>/dev/null || true

    if [[ -f "$HOME/.local/share/krunnerstaterc" ]]; then
        rm -f "$HOME/.local/share/krunnerstaterc"
    fi

    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file krunnerrc --group General --key PastQueries "[]" >/dev/null 2>&1 || true
    elif command -v kwriteconfig5 >/dev/null 2>&1; then
        kwriteconfig5 --file krunnerrc --group General --key PastQueries "[]" >/dev/null 2>&1 || true
    fi

    rm -rf "$HOME/.cache/krunner"/* 2>/dev/null || true
    rm -rf "$HOME/.cache/plasmashell"* 2>/dev/null || true
    rm -f "$HOME/.cache/org.kde.dirmodel-cache.kcache" 2>/dev/null || true

    if pgrep -x plasmashell >/dev/null 2>&1; then
        killall plasmashell 2>/dev/null || true
        nohup plasmashell >/dev/null 2>&1 &
    fi

    nohup krunner >/dev/null 2>&1 &
    log_ok "KRunner e cache do Plasma atualizados."
}

show_summary() {
    echo
    log_info "--- Resumo ---"
    echo "Arquivos .desktop analisados : $SCANNED"
    echo "Atalhos inválidos encontrados : $INVALID"
    echo "Remoções concluídas          : $REMOVED"
    echo "Falhas de remoção            : $FAILED"
    echo "Ícones Steam corrigidos      : $STEAM_FIXED"
    echo
    log_ok "Processo finalizado."
}

main() {
    prepare_sudo
    teste_and_remove_flatpak
    teste_and_remove_snap
    cleanup_orphans
    cleanup_flatpak_snap_cache
    fix_steam_shortcut_icons
    scan_and_clean_desktop_entries
    refresh_kde
    show_summary
}

main
