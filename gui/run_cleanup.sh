#!/bin/bash
#
# run_cleanup.sh — Backend da GUI BigLinuxCleaner
# Recebe seleção de tarefas via POST ($p_*) e executa a limpeza.
# Saída é HTML que o BigBashView renderiza como resultado.
#

GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)"
LIB_DIR="$GUI_DIR/../lib"

# Carrega bibliotecas
if [[ -f "$LIB_DIR/detect_de.sh" ]]; then
    source "$LIB_DIR/detect_de.sh"
    detect_desktop_environment >/dev/null
fi
if [[ -f "$LIB_DIR/refresh_de.sh" ]]; then
    source "$LIB_DIR/refresh_de.sh"
fi

# ─── Diretórios para verificar .desktop ───
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
ORPHANS_REMOVED=0
FLATPAK_CLEANED=0
SNAP_CLEANED=0

# ─── Log buffer (para HTML) ───
LOG_BUFFER=""

log_line() {
    local cls="$1"
    shift
    LOG_BUFFER="${LOG_BUFFER}<span class=\"log-${cls}\">$*</span>\n"
}

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
    if command -v sudo >/dev/null 2>&1 && need_sudo; then
        sudo -v 2>/dev/null || true
    fi
}

# ─── Funções de limpeza (reutilizadas do cleaner.sh) ───

extract_exec_bin() {
    local line="$1" cmd
    cmd="${line#Exec=}"
    cmd="${cmd#${cmd%%[![:space:]]*}}"
    while [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+ ]]; do
        cmd="${cmd#${BASH_REMATCH[0]}}"
    done
    if [[ "$cmd" =~ ^\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"; return
    fi
    echo "${cmd%%[[:space:]]*}"
}

is_exec_valid() {
    local exec_bin="$1"
    [[ -z "$exec_bin" ]] && return 1
    if [[ "$exec_bin" == /* ]]; then [[ -x "$exec_bin" ]]; return; fi
    command -v "$exec_bin" >/dev/null 2>&1
}

remove_desktop_file() {
    local file="$1"
    if rm -f "$file" 2>/dev/null; then return 0; fi
    if command -v sudo >/dev/null 2>&1; then
        sudo chmod u+w "$file" 2>/dev/null || true
        sudo rm -f "$file"; return
    fi
    return 1
}

extract_snap_name_from_desktop() {
    local file="$1" snap_name base
    snap_name="$(grep -m 1 '^X-SnapInstanceName=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
    if [[ -n "$snap_name" ]]; then echo "$snap_name"; return; fi
    base="$(basename "$file" .desktop)"
    if [[ "$base" == snap.*.* ]]; then snap_name="${base#snap.}"; snap_name="${snap_name%%.*}"; echo "$snap_name"; return; fi
    if [[ "$base" == *_* ]]; then echo "${base%%_*}"; return; fi
    echo "$base"
}

# ─── Tarefa: Pacotes órfãos ───
run_orphans() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "📦 Verificando pacotes órfãos..."

    if ! command -v pacman >/dev/null 2>&1; then
        log_line "warn" "pacman não encontrado — ignorado."
        return
    fi

    local orphans
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)

    if ((${#orphans[@]} == 0)); then
        log_line "ok" "Nenhum pacote órfão encontrado."
        return
    fi

    log_line "info" "Encontrados ${#orphans[@]} pacotes órfãos."
    if sudo pacman -Rns --noconfirm "${orphans[@]}" 2>&1 | while IFS= read -r line; do
        log_line "info" "  $line"
    done; then
        ORPHANS_REMOVED=${#orphans[@]}
        log_line "ok" "Pacotes órfãos removidos: ${#orphans[@]}"
    else
        log_line "err" "Erro ao remover pacotes órfãos."
    fi
}

# ─── Tarefa: Atalhos quebrados ───
run_shortcuts() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "🔗 Verificando atalhos quebrados..."

    local dir file app_name exec_line exec_bin

    for dir in "${DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            ((SCANNED += 1))
            app_name="$(grep -m 1 '^Name=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
            exec_line="$(grep -m 1 '^Exec=' "$file" 2>/dev/null || true)"
            [[ -n "$exec_line" ]] || continue
            exec_bin="$(extract_exec_bin "$exec_line")"

            if ! is_exec_valid "$exec_bin"; then
                ((INVALID += 1))
                log_line "warn" "  Inval: ${app_name:-Sem Nome} ($exec_bin)"
                if remove_desktop_file "$file"; then
                    ((REMOVED += 1))
                else
                    ((FAILED += 1))
                fi
            fi
        done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done

    log_line "ok" "Atalhos verificados: $SCANNED | Removidos: $REMOVED | Falhas: $FAILED"
}

# ─── Tarefa: Ícones Steam ───
run_steam() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "🎮 Verificando ícones da Steam..."

    if ! command -v curl >/dev/null 2>&1; then
        log_line "warn" "curl não encontrado — ignorado."
        return
    fi

    local dir file exec_line icon_line icon_value game_id
    local hicolor_256="$HOME/.local/share/icons/hicolor/256x256/apps"
    local tmp_dir="$HOME/.local/share/icons/steam-games"
    local has_convert=0
    command -v convert >/dev/null 2>&1 && has_convert=1
    command -v magick >/dev/null 2>&1 && has_convert=1

    mkdir -p "$hicolor_256" "$tmp_dir"

    for dir in "${DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            exec_line="$(grep -m 1 '^Exec=' "$file" 2>/dev/null || true)"
            if [[ ! "$exec_line" =~ steam://rungameid/([0-9]+) ]]; then continue; fi
            game_id="${BASH_REMATCH[1]}"
            icon_line="$(grep -m 1 '^Icon=' "$file" 2>/dev/null || true)"
            icon_value="${icon_line#Icon=}"

            local marker="$tmp_dir/${game_id}.square"
            if [[ -s "$HOME/.local/share/icons/hicolor/256x256/apps/steam_icon_${game_id}.png" && -f "$marker" ]]; then
                continue
            fi

            log_line "warn" "  Baixando ícone: $(basename "$file" .desktop) (ID: $game_id)"

            local tmp_img="$tmp_dir/${game_id}_tmp.img"
            local cdn url downloaded=0
            for cdn in "cdn.akamai.steamstatic.com" "cdn.cloudflare.steamstatic.com"; do
                for url in \
                    "https://${cdn}/steam/apps/${game_id}/library_600x900_2x.jpg" \
                    "https://${cdn}/steam/apps/${game_id}/library_600x900.jpg" \
                    "https://${cdn}/steam/apps/${game_id}/header.jpg"; do
                    if curl -fsSL --max-time 10 "$url" -o "$tmp_img" 2>/dev/null && [[ -s "$tmp_img" ]]; then
                        downloaded=1; break 2
                    fi
                done
            done

            if [[ $downloaded -eq 0 ]]; then
                log_line "err" "  Falha ao baixar ícone do jogo $game_id"
                rm -f "$tmp_img"; continue
            fi

            local final_icon=""
            local theme_icon="$hicolor_256/steam_icon_${game_id}.png"

            if ((has_convert)); then
                if convert "$tmp_img" -background none -gravity center -resize "256x256^" -extent 256x256 "$theme_icon" 2>/dev/null; then
                    final_icon="$theme_icon"
                    touch "$marker"
                fi
                rm -f "$tmp_img"
            else
                mv "$tmp_img" "$tmp_dir/${game_id}.jpg"
                final_icon="$tmp_dir/${game_id}.jpg"
            fi

            if [[ -n "$final_icon" && -s "$final_icon" ]]; then
                if [[ "$final_icon" == "$theme_icon" ]]; then
                    [[ "$icon_value" != "steam_icon_${game_id}" ]] && sed -i "s|^Icon=.*|Icon=steam_icon_${game_id}|" "$file"
                else
                    sed -i "s|^Icon=.*|Icon=${final_icon}|" "$file"
                fi
                ((STEAM_FIXED += 1))
                log_line "ok" "  Ícone corrigido: $(basename "$file" .desktop)"
            fi
        done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done

    log_line "ok" "Ícones Steam corrigidos: $STEAM_FIXED"
}

# ─── Tarefa: Flatpak órfãos ───
run_flatpak_orphan() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "📦 Verificando atalhos Flatpak..."

    if ! command -v flatpak >/dev/null 2>&1; then
        log_line "warn" "flatpak não encontrado — ignorado."
        return
    fi

    local -A installed_apps=()
    while IFS= read -r app_id; do
        [[ -n "$app_id" ]] && installed_apps["$app_id"]=1
    done < <(flatpak list --app --columns=application 2>/dev/null || true)

    local file app_name app_id local count=0
    for local_dir in "$HOME/.local/share/flatpak/exports/share/applications" "/var/lib/flatpak/exports/share/applications"; do
        [[ -d "$local_dir" ]] || continue
        while IFS= read -r -d '' file; do
            app_name="$(grep -m 1 '^Name=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
            app_id="$(basename "$file" .desktop)"
            if [[ -z "${installed_apps[$app_id]+x}" ]]; then
                log_line "warn" "  Órfão: ${app_name:-$app_id}"
                if remove_desktop_file "$file"; then
                    ((count += 1))
                fi
            fi
        done < <(find "$local_dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done

    FLATPAK_CLEANED=$count
    log_line "ok" "Atalhos Flatpak removidos: $count"
}

# ─── Tarefa: Snap órfãos ───
run_snap_orphan() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "📦 Verificando atalhos Snap..."

    if ! command -v snap >/dev/null 2>&1; then
        log_line "warn" "snap não encontrado — ignorado."
        return
    fi

    local -A installed_snaps=()
    while IFS= read -r snap_name; do
        [[ -n "$snap_name" ]] && installed_snaps["$snap_name"]=1
    done < <(snap list 2>/dev/null | awk 'NR>1{print $1}')

    local file app_name snap_name local count=0
    while IFS= read -r -d '' file; do
        app_name="$(grep -m 1 '^Name=' "$file" 2>/dev/null | cut -d'=' -f2- || true)"
        snap_name="$(extract_snap_name_from_desktop "$file")"
        if [[ -z "${installed_snaps[$snap_name]+x}" ]]; then
            log_line "warn" "  Órfão: ${app_name:-$snap_name}"
            if remove_desktop_file "$file"; then
                ((count += 1))
            fi
        fi
    done < <(find "/var/lib/snapd/desktop/applications" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)

    SNAP_CLEANED=$count
    log_line "ok" "Atalhos Snap removidos: $count"
}

# ─── Tarefa: Cache Flatpak/Snap ───
run_cache() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "🗑️ Limpando cache Flatpak/Snap..."

    if command -v flatpak >/dev/null 2>&1; then
        flatpak uninstall --unused -y >/dev/null 2>&1 || true
        rm -rf "$HOME/.cache/flatpak"/* 2>/dev/null || true
        command -v sudo >/dev/null 2>&1 && sudo rm -rf /var/tmp/flatpak-cache/* 2>/dev/null || true
        log_line "ok" "Cache Flatpak limpo."
    fi

    if command -v snap >/dev/null 2>&1; then
        while IFS= read -r snap_line; do
            [[ -n "$snap_line" ]] || continue
            local snap_name snap_rev
            snap_name="$(awk '{print $1}' <<<"$snap_line")"
            snap_rev="$(awk '{print $2}' <<<"$snap_line")"
            [[ -n "$snap_name" && -n "$snap_rev" ]] && sudo snap remove "$snap_name" --revision="$snap_rev" >/dev/null 2>&1 || true
        done < <(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}')
        command -v sudo >/dev/null 2>&1 && sudo rm -f /var/lib/snapd/cache/*.snap 2>/dev/null || true
        log_line "ok" "Cache Snap limpo."
    fi

    if ! command -v flatpak >/dev/null 2>&1 && ! command -v snap >/dev/null 2>&1; then
        log_line "warn" "Flatpak e Snap não encontrados — ignorado."
    fi
}

# ─── Tarefa: Refresh do DE ───
run_refresh() {
    log_line "separator" "────────────────────────────────────────"
    log_line "info" "🔄 Atualizando menu do Desktop Environment..."

    if [[ -n "${DESKTOP_ENVIRONMENT:-}" ]] && declare -f refresh_desktop_environment >/dev/null 2>&1; then
        refresh_desktop_environment 2>&1 | while IFS= read -r line; do
            log_line "info" "  $line"
        done
    elif command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        log_line "ok" "update-desktop-database executado."
    fi

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi

    log_line "ok" "Menu atualizado."
}

# ═══════════════════════════════════════════
# EXECUÇÃO PRINCIPAL
# ═══════════════════════════════════════════

prepare_sudo

# Executa tarefas selecionadas (recebidas via POST como p_task_*)
[[ "${p_task_orphans:-}" == "1" ]]         && run_orphans
[[ "${p_task_shortcuts:-}" == "1" ]]      && run_shortcuts
[[ "${p_task_steam:-}" == "1" ]]          && run_steam
[[ "${p_task_flatpak_orphan:-}" == "1" ]] && run_flatpak_orphan
[[ "${p_task_snap_orphan:-}" == "1" ]]    && run_snap_orphan
[[ "${p_task_cache:-}" == "1" ]]          && run_cache
[[ "${p_task_refresh:-}" == "1" ]]        && run_refresh

# ═══════════════════════════════════════════
# GERA HTML DE RESULTADO
# ═══════════════════════════════════════════

TOTAL_TASKS=0
COMPLETED_TASKS=0
[[ "${p_task_orphans:-}" == "1" ]]         && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))
[[ "${p_task_shortcuts:-}" == "1" ]]      && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))
[[ "${p_task_steam:-}" == "1" ]]          && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))
[[ "${p_task_flatpak_orphan:-}" == "1" ]] && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))
[[ "${p_task_snap_orphan:-}" == "1" ]]    && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))
[[ "${p_task_cache:-}" == "1" ]]          && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))
[[ "${p_task_refresh:-}" == "1" ]]        && ((TOTAL_TASKS++)) && ((COMPLETED_TASKS++))

echo "
<!DOCTYPE html>
<html lang=\"pt-BR\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>BigLinuxCleaner — Resultados</title>
    <link rel=\"stylesheet\" href=\"css/style.css\">
</head>
<body>

    <!-- Header -->
    <header class=\"app-header\">
        <img class=\"logo\" src=\"$GUI_DIR/../icon-256.png\" alt=\"BigLinuxCleaner\"
             onerror=\"this.style.display='none'\">
        <div class=\"title-group\">
            <h1>BigLinuxCleaner</h1>
            <div class=\"subtitle\">Limpeza concluída</div>
        </div>
    </header>

    <!-- Results -->
    <main class=\"app-content\">

        <!-- Summary Stats -->
        <div class=\"results-summary\">
            <div class=\"stat-card\">
                <div class=\"stat-value blue\">$TOTAL_TASKS</div>
                <div class=\"stat-label\">Tarefas</div>
            </div>
            <div class=\"stat-card\">
                <div class=\"stat-value green\">$ORPHANS_REMOVED</div>
                <div class=\"stat-label\">Órfãos</div>
            </div>
            <div class=\"stat-card\">
                <div class=\"stat-value yellow\">$REMOVED</div>
                <div class=\"stat-label\">Atalhos</div>
            </div>
            <div class=\"stat-card\">
                <div class=\"stat-value green\">$STEAM_FIXED</div>
                <div class=\"stat-label\">Steam</div>
            </div>
        </div>

        <!-- Log Output -->
        <div class=\"log-container\">
            <div class=\"log-header\">
                <span>Log de execução</span>
            </div>
            <div class=\"log-output\" id=\"log-output\">
$(echo -e "$LOG_BUFFER")
            </div>
        </div>

        <!-- Back Button -->
        <div class=\"action-bar\">
            <div class=\"task-count\">
                Processo finalizado
            </div>
            <a href=\"execute\$\./index.sh.html\" class=\"btn btn-primary\">
                <svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"15 18 9 12 15 6\"></polyline></svg>
                Voltar
            </a>
        </div>

    </main>

    <footer class=\"app-footer\">
        BigLinuxCleaner v2.0 · <a href=\"https://github.com/zonaro/BigLinuxCleaner\" target=\"_blank\">GitHub</a> ·
        Big Linux / BigCommunity
    </footer>

    <script>
        // Auto-scroll log to bottom
        var log = document.getElementById('log-output');
        if (log) log.scrollTop = log.scrollHeight;
    </script>
</body>
</html>
"
