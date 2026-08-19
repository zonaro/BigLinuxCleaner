#!/bin/bash

# curl -fsSL https://raw.githubusercontent.com/zonaro/BigLinuxCleaner/main/cleaner.sh | bash
# BigLinuxCleaner — Limpeza e manutenção para Big Linux / BigCommunity (KDE, GNOME, XFCE, Cinnamon)

set -Eeuo pipefail

# ─── Carrega bibliotecas ───
LIB_DIR="$(dirname "${BASH_SOURCE[0]:-}")/lib"
source "$LIB_DIR/detect_de.sh"
source "$LIB_DIR/refresh_de.sh"

# ─── Cores ───
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Diretórios para verificar .desktop (Sistema, Usuário, Flatpak, Snap) ───
DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
    "/var/lib/flatpak/exports/share/applications"
    "/var/lib/snapd/desktop/applications"
)

# ─── Contadores ───
SCANNED=0
INVALID=0
REMOVED=0
FAILED=0
STEAM_FIXED=0

# ─── Logging ───
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERRO]${NC} $*"; }

trap 'log_err "Falha na linha ${LINENO}. Abortando."' ERR

# ─── Utilitários ───
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

# ─── Limpeza de pacotes órfãos (pacman) ───
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

# ─── Remove atalhos Flatpak órfãos ───
remove_flatpak_orphans() {
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

# ─── Extrai nome do Snap do .desktop ───
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

# ─── Remove atalhos Snap órfãos ───
remove_snap_orphans() {
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

# ─── Limpa cache Flatpak/Snap ───
cleanup_flatpak_snap_cache() {
    local snap_line snap_name snap_rev

    log_info "Limpando cache e resíduos do Flatpak/Snap..."

    if command -v flatpak >/dev/null 2>&1; then
        flatpak uninstall --unused -y >/dev/null 2>&1 || true
        rm -rf "$HOME/.cache/flatpak"/* 2>/dev/null || true
        if command -v sudo >/dev/null 2>&1; then
            sudo rm -rf /var/tmp/flatpak-cache/* 2>/dev/null || true
        fi
        log_ok "Limpeza do Flatpak concluída."
    else
        log_warn "flatpak não encontrado; limpeza do Flatpak ignorada."
    fi

    if command -v snap >/dev/null 2>&1; then
        while IFS= read -r snap_line; do
            [[ -n "$snap_line" ]] || continue
            snap_name="$(awk '{print $1}' <<<"$snap_line")"
            snap_rev="$(awk '{print $2}' <<<"$snap_line")"
            if [[ -n "$snap_name" && -n "$snap_rev" ]]; then
                sudo snap remove "$snap_name" --revision="$snap_rev" >/dev/null 2>&1 || true
            fi
        done < <(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}')

        if command -v sudo >/dev/null 2>&1; then
            sudo rm -f /var/lib/snapd/cache/*.snap 2>/dev/null || true
        fi
        log_ok "Limpeza do Snap concluída."
    else
        log_warn "snap não encontrado; limpeza do Snap ignorada."
    fi
}

# ─── Extrai binário do Exec= ───
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

# ─── Verifica se executável é válido ───
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

# ─── Remove arquivo .desktop ───
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

# ─── Verifica validade do ícone ───
is_icon_valid() {
    local icon_value="$1"
    local min_size="${2:-0}"
    local size px found=""

    [[ -z "$icon_value" ]] && return 1

    if [[ "$icon_value" == /* ]]; then
        [[ -s "$icon_value" ]] && return 0
        return 1
    fi

    for size in 256x256 128x128 64x64 48x48 32x32 16x16 scalable; do
        if [[ -s "$HOME/.local/share/icons/hicolor/$size/apps/$icon_value.png" ]] ||
           [[ -s "$HOME/.local/share/icons/hicolor/$size/apps/$icon_value.svg" ]] ||
           [[ -s "/usr/share/icons/hicolor/$size/apps/$icon_value.png" ]] ||
           [[ -s "/usr/share/icons/hicolor/$size/apps/$icon_value.svg" ]]; then
            found="$size"
            break
        fi
    done

    [[ -z "$found" ]] && return 1
    [[ "$found" == "scalable" ]] && return 0

    px="${found%x*}"
    (( px >= min_size ))
}

# ─── Baixa imagem da Steam CDN ───
download_steam_image() {
    local game_id="$1"
    local dest="$2"
    local cdn url

    for cdn in "cdn.akamai.steamstatic.com" "cdn.cloudflare.steamstatic.com"; do
        for url in \
            "https://${cdn}/steam/apps/${game_id}/library_600x900_2x.jpg" \
            "https://${cdn}/steam/apps/${game_id}/library_600x900.jpg" \
            "https://${cdn}/steam/apps/${game_id}/header.jpg"; do
            if curl -fsSL --max-time 10 "$url" -o "$dest" 2>/dev/null && [[ -s "$dest" ]]; then
                return 0
            fi
        done
    done

    return 1
}

# ─── Corrige ícones da Steam ───
fix_steam_shortcut_icons() {
    local dir file exec_line icon_line icon_value game_id
    local hicolor_256="$HOME/.local/share/icons/hicolor/256x256/apps"
    local tmp_dir="$HOME/.local/share/icons/steam-games"
    local has_convert=0

    if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
        has_convert=1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl não encontrado; correção de ícones da Steam ignorada."
        return
    fi

    log_info "--- Corrigindo ícones de atalhos da Steam ---"

    mkdir -p "$hicolor_256" "$tmp_dir"

    for dir in "${DIRS[@]}"; do
        [[ -d "$dir" ]] || continue

        while IFS= read -r -d '' file; do
            exec_line="$(grep -m 1 '^Exec=' "$file" 2>/dev/null || true)"

            if [[ ! "$exec_line" =~ steam://rungameid/([0-9]+) ]]; then
                continue
            fi

            game_id="${BASH_REMATCH[1]}"

            icon_line="$(grep -m 1 '^Icon=' "$file" 2>/dev/null || true)"
            icon_value="${icon_line#Icon=}"

            local marker="$tmp_dir/${game_id}.square"

            if is_icon_valid "$icon_value" 128 && [[ -f "$marker" ]]; then
                continue
            fi

            log_warn "Ícone inválido detectado: $(basename "$file" .desktop)"
            echo -e "  Arquivo: $file"
            echo -e "  Game ID: ${YELLOW}${game_id}${NC}"
            echo -e "  Icon atual: ${icon_value:-vazio}"

            local final_icon=""
            local theme_icon="$hicolor_256/steam_icon_${game_id}.png"

            if [[ -s "$theme_icon" && -f "$marker" ]]; then
                final_icon="$theme_icon"
            else
                local tmp_img="$tmp_dir/${game_id}_tmp.img"

                log_info "Baixando ícone do jogo (Steam AppID: $game_id)..."
                if ! download_steam_image "$game_id" "$tmp_img"; then
                    log_err "Falha ao baixar ícone do jogo $game_id — pulando."
                    rm -f "$tmp_img"
                    continue
                fi

                if ((has_convert)); then
                    if convert "$tmp_img" \
                        -background none \
                        -gravity center \
                        -resize "256x256^" \
                        -extent 256x256 \
                        "$theme_icon" 2>/dev/null; then
                        final_icon="$theme_icon"
                        touch "$marker"
                    else
                        log_err "Falha ao converter o ícone do jogo $game_id."
                        rm -f "$tmp_img"
                        continue
                    fi
                    rm -f "$tmp_img"
                else
                    mv "$tmp_img" "$tmp_dir/${game_id}.jpg"
                    final_icon="$tmp_dir/${game_id}.jpg"
                fi
            fi

            if [[ -z "$final_icon" || ! -s "$final_icon" ]]; then
                log_err "Ícone do jogo $game_id não pôde ser obtido."
                continue
            fi

            if [[ "$final_icon" == "$theme_icon" ]]; then
                if [[ "$icon_value" != "steam_icon_${game_id}" ]]; then
                    sed -i "s|^Icon=.*|Icon=steam_icon_${game_id}|" "$file"
                fi
            else
                sed -i "s|^Icon=.*|Icon=${final_icon}|" "$file"
            fi

            ((STEAM_FIXED += 1))
            log_ok "Ícone corrigido: $(basename "$file" .desktop) → $final_icon"

        done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done

    if ((STEAM_FIXED > 0)); then
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
        fi
        log_ok "Total de ícones da Steam corrigidos: $STEAM_FIXED"
    else
        log_ok "Nenhum ícone da Steam precisou de correção."
    fi
}

# ─── Varredura e limpeza de atalhos quebrados ───
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

# ─── Refresh universal do Desktop Environment ───
refresh_desktop() {
    refresh_desktop_environment
}

# ─── Resumo final ───
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

# ─── Main ───
main() {
    # Detecta DE no início
    detect_desktop_environment
    log_info "BigLinuxCleaner iniciado no ${DESKTOP_ENVIRONMENT_PRETTY} (${DESKTOP_ENVIRONMENT})"

    prepare_sudo
    remove_flatpak_orphans
    remove_snap_orphans
    cleanup_orphans
    cleanup_flatpak_snap_cache
    fix_steam_shortcut_icons
    scan_and_clean_desktop_entries
    refresh_desktop
    show_summary
}

main
