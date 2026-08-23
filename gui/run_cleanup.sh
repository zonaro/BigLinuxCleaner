#!/bin/bash
#
# run_cleanup.sh — Backend da GUI BigLinuxCleaner (modo dual)
#
# Modo A (default, via POST execute$./run_cleanup.sh):
#   Cria uma sessao, dispara um worker DETACHED em background e retorna
#   imediatamente a pagina de progresso (que faz polling do status/log).
#
# Modo B (--worker SESSION_DIR):
#   Executa as tarefas de limpeza, gravando o log linha-a-linha em log.txt
#   e atualizando status.json atomicamente via python3.
#
# O streaming via execute$ e impossivel (BBV usa communicate()), por isso
# o worker roda destacado e a GUI consulta /api/file + tail_log.sh.html.
#

# Caminhos
GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)"
LIB_DIR="$GUI_DIR/../lib"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"

# Diretorio base de cache das sessoes
BLC_CACHE_BASE="$HOME/.cache/biglinuxcleaner"

# Carrega bibliotecas (como no script original)
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

# ─── Log de arquivo (linha-a-linha, sem buffer) ───
# Formato de cada linha: "<classe>\t<mensagem>" — a classe permite colorir
# no lado do cliente sem usar innerHTML (evita XSS e preserva o estilo).
BLC_LOG_FILE=""
BLC_STATUS_FILE=""

log_line() {
    [[ -n "${BLC_LOG_FILE:-}" ]] || return 0
    local cls="$1"
    shift
    printf '%s\t%s\n' "$cls" "$*" >> "$BLC_LOG_FILE" || true
}

# Wrappers para as funcoes de log usadas por lib/refresh_de.sh
log_info() { log_line "info" "$*"; }
log_ok()   { log_line "ok" "$*"; }
log_warn() { log_line "warn" "$*"; }

# ─── Escrita atomica de status.json (unica fonte de verdade) ───
# Recebe: <running> <current_task> <done> <total>
# As estatisticas vem das variaveis globais do worker.
blc_write_status() {
    local running="${1:-true}" current="${2:-}" done_n="${3:-0}" total_n="${4:-0}"
    BLC_PY_RUNNING="$running" \
    BLC_PY_CURRENT="$current" \
    BLC_PY_DONE="$done_n" \
    BLC_PY_TOTAL="$total_n" \
    BLC_PY_ORPHANS="${ORPHANS_REMOVED:-0}" \
    BLC_PY_SHORTCUTS="${REMOVED:-0}" \
    BLC_PY_SHORTCUTS_FAILED="${FAILED:-0}" \
    BLC_PY_STEAM="${STEAM_FIXED:-0}" \
    BLC_PY_FLATPAK="${FLATPAK_CLEANED:-0}" \
    BLC_PY_SNAP="${SNAP_CLEANED:-0}" \
    python3 - "$BLC_STATUS_FILE" <<'PYEOF' || true
import json, os, sys
path = sys.argv[1]
def i(k):
    v = os.environ.get(k, "0") or "0"
    try:
        return int(v)
    except Exception:
        return 0
data = {
    "running": os.environ.get("BLC_PY_RUNNING", "true") == "true",
    "current_task": os.environ.get("BLC_PY_CURRENT", ""),
    "done": i("BLC_PY_DONE"),
    "total": i("BLC_PY_TOTAL"),
    "stats": {
        "orphans_removed": i("BLC_PY_ORPHANS"),
        "shortcuts_removed": i("BLC_PY_SHORTCUTS"),
        "shortcuts_failed": i("BLC_PY_SHORTCUTS_FAILED"),
        "steam_fixed": i("BLC_PY_STEAM"),
        "flatpak_removed": i("BLC_PY_FLATPAK"),
        "snap_removed": i("BLC_PY_SNAP"),
    },
}
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
os.replace(tmp, path)
PYEOF
}

# ─── Prune de sessoes antigas (mantem 5 mais recentes) ───
blc_prune_sessions() {
    local -a old
    shopt -s nullglob
    old=($(ls -dt "$BLC_CACHE_BASE"/session-* 2>/dev/null))
    shopt -u nullglob
    local count=${#old[@]}
    local i
    for ((i = 5; i < count; i++)); do
        rm -rf "${old[i]}" 2>/dev/null || true
    done
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
# MODO A — Pagina de progresso (POST)
# ═══════════════════════════════════════════

main_post() {
    # Tarefas selecionadas via POST.
    # O BBV repassa os campos do formulario como variaveis de ambiente SEM
    # prefixo (ex.: $task_orphans). Mantemos o fallback com prefixo "p_"
    # apenas por compatibilidade com versoes antigas do BBV.
    local t_orphans="${task_orphans:-${p_task_orphans:-0}}"
    local t_shortcuts="${task_shortcuts:-${p_task_shortcuts:-0}}"
    local t_steam="${task_steam:-${p_task_steam:-0}}"
    local t_flatpak="${task_flatpak_orphan:-${p_task_flatpak_orphan:-0}}"
    local t_snap="${task_snap_orphan:-${p_task_snap_orphan:-0}}"
    local t_cache="${task_cache:-${p_task_cache:-0}}"
    local t_refresh="${task_refresh:-${p_task_refresh:-0}}"

    # Cria diretorio de sessao
    local ts
    ts="$(date +%Y%m%d-%H%M%S)-$$"
    local session_dir="$BLC_CACHE_BASE/session-$ts"
    mkdir -p "$session_dir" 2>/dev/null || {
        print_fatal_page
        return 1
    }

    BLC_STATUS_FILE="$session_dir/status.json"
    BLC_LOG_FILE="$session_dir/log.txt"

    # Prune de sessoes antigas (best-effort)
    blc_prune_sessions || true

    # Grava selecao de tarefas
    {
        echo "TASK_ORPHANS=${t_orphans}"
        echo "TASK_SHORTCUTS=${t_shortcuts}"
        echo "TASK_STEAM=${t_steam}"
        echo "TASK_FLATPAK_ORPHAN=${t_flatpak}"
        echo "TASK_SNAP_ORPHAN=${t_snap}"
        echo "TASK_CACHE=${t_cache}"
        echo "TASK_REFRESH=${t_refresh}"
    } > "$session_dir/tasks.env" 2>/dev/null || {
        print_fatal_page
        return 1
    }

    # Total de tarefas selecionadas
    local total=0
    [[ "$t_orphans" == "1" ]]   && total=$((total + 1))
    [[ "$t_shortcuts" == "1" ]] && total=$((total + 1))
    [[ "$t_steam" == "1" ]]     && total=$((total + 1))
    [[ "$t_flatpak" == "1" ]]   && total=$((total + 1))
    [[ "$t_snap" == "1" ]]      && total=$((total + 1))
    [[ "$t_cache" == "1" ]]     && total=$((total + 1))
    [[ "$t_refresh" == "1" ]]   && total=$((total + 1))

    # Inicializa status.json (running: true)
    ORPHANS_REMOVED=0; REMOVED=0; FAILED=0; STEAM_FIXED=0; FLATPAK_CLEANED=0; SNAP_CLEANED=0
    blc_write_status true "" 0 "$total"

    # Dispara o worker DETACHED (sobrevive quando este parent sai)
    setsid nohup bash "$SCRIPT_PATH" --worker "$session_dir" >/dev/null 2>&1 < /dev/null &
    disown || true

    # Retorna a pagina de progresso imediatamente
    local de_badge="${DESKTOP_ENVIRONMENT_PRETTY:-Desconhecido}"
    print_progress_page "$(basename "$session_dir")" "$de_badge"
}

print_fatal_page() {
    cat <<'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>BigLinuxCleaner — Erro</title></head>
<body style="background:#0d1117;color:#e6edf3;font-family:sans-serif;padding:40px;">
<h1>Erro ao iniciar a limpeza</h1>
<p>Não foi possível criar o diretório de sessão. Verifique o espaço em disco e as permissões de ~/.cache.</p>
<a href="execute$./index.sh.html" style="color:#2f81f7;">Voltar</a>
</body>
</html>
HTML
}

print_progress_page() {
    local sid="$1"
    local de_badge="$2"
    # Substituicao via bash (literal, sem os metacaracteres do sed) para
    # nao quebrar caso o nome do DE contenha "/", "&" etc.
    local page
    page="$(cat <<'PROGRESS_HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>BigLinuxCleaner — Progresso</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  background: #0d1117;
  color: #e6edf3;
  font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.app-header {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 24px 32px;
  background: #161b22;
  border-bottom: 1px solid #30363d;
}
.app-header .title-group { flex: 1; }
.app-header h1 { font-size: 20px; font-weight: 700; }
.app-header .subtitle { font-size: 13px; color: #8b949e; margin-top: 2px; }
.de-badge {
  padding: 4px 12px;
  border-radius: 20px;
  background: rgba(6,182,212,0.15);
  color: #06b6d4;
  font-size: 12px;
  font-weight: 600;
  white-space: nowrap;
}
.app-content {
  flex: 1;
  padding: 24px 32px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  max-width: 900px;
  margin: 0 auto;
  width: 100%;
}
.progress-wrap {
  background: #161b22;
  border: 1px solid #30363d;
  border-radius: 10px;
  padding: 18px 20px;
}
.progress-track {
  height: 8px;
  background: #1c2333;
  border-radius: 6px;
  overflow: hidden;
  margin-bottom: 10px;
}
.progress-bar {
  height: 100%;
  width: 0%;
  background: linear-gradient(90deg, #2f81f7, #06b6d4);
  border-radius: 6px;
  transition: width 0.4s ease;
}
.progress-label { font-size: 13px; color: #8b949e; }
.current-task {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 12px;
  font-size: 14px;
  color: #e6edf3;
}
.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255,255,255,0.2);
  border-top-color: #06b6d4;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.results-summary {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
}
.stat-card {
  flex: 1;
  min-width: 120px;
  background: #1c2333;
  border: 1px solid #30363d;
  border-radius: 10px;
  padding: 18px;
  text-align: center;
}
.stat-value {
  font-size: 30px;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 6px;
}
.stat-value.blue { color: #2f81f7; }
.stat-value.green { color: #3fb950; }
.stat-value.yellow { color: #d29922; }
.stat-label { font-size: 13px; color: #8b949e; }
.log-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: #161b22;
  border: 1px solid #30363d;
  border-radius: 10px;
  overflow: hidden;
  min-height: 220px;
}
.log-header {
  padding: 12px 16px;
  background: #1c2333;
  border-bottom: 1px solid #30363d;
  font-weight: 600;
  font-size: 14px;
}
.log-output {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 13px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}
.log-info { color: #06b6d4; }
.log-ok { color: #3fb950; }
.log-warn { color: #d29922; }
.log-err { color: #f85149; }
.log-separator { color: #6e7681; opacity: 0.5; }
.action-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 0 0;
  border-top: 1px solid #30363d;
}
.task-count { font-size: 14px; color: #8b949e; font-weight: 500; }
.btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 24px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  background: linear-gradient(135deg, #2f81f7, #06b6d4);
  color: #fff;
}
.btn:hover { opacity: 0.9; }
.app-footer {
  padding: 16px 32px;
  text-align: center;
  font-size: 12px;
  color: #6e7681;
  border-top: 1px solid #30363d;
  background: #161b22;
}
.app-footer a { color: #8b949e; text-decoration: none; }
</style>
</head>
<body>
<header class="app-header">
  <div class="title-group">
    <h1>BigLinuxCleaner</h1>
    <div class="subtitle" id="subtitle">Limpeza em andamento...</div>
  </div>
  <span class="de-badge">DE: __DE_BADGE__</span>
</header>
<main class="app-content">
  <div class="progress-wrap">
    <div class="progress-track"><div class="progress-bar" id="progress-bar"></div></div>
    <div class="progress-label" id="progress-label">0 de 0 tarefas</div>
    <div class="current-task">
      <span class="spinner" id="spinner"></span>
      <span id="current-task">Aguardando...</span>
    </div>
  </div>
  <div class="results-summary">
    <div class="stat-card">
      <div class="stat-value blue" id="stat-tasks">0/0</div>
      <div class="stat-label">Tarefas</div>
    </div>
    <div class="stat-card">
      <div class="stat-value green" id="stat-orphans">0</div>
      <div class="stat-label">Orfaos</div>
    </div>
    <div class="stat-card">
      <div class="stat-value yellow" id="stat-shortcuts">0</div>
      <div class="stat-label">Atalhos</div>
    </div>
    <div class="stat-card">
      <div class="stat-value green" id="stat-steam">0</div>
      <div class="stat-label">Steam</div>
    </div>
  </div>
  <div class="log-container">
    <div class="log-header"><span>Log de execucao</span></div>
    <div class="log-output" id="log-output"></div>
  </div>
  <div class="action-bar">
    <div class="task-count" id="action-text">Executando...</div>
    <a href="execute$./index.sh.html" class="btn">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
      Voltar
    </a>
  </div>
</main>
<footer class="app-footer">
  BigLinuxCleaner v2.0 &middot; <a href="https://github.com/zonaro/BigLinuxCleaner" target="_blank">GitHub</a> &middot;
  Big Linux / BigCommunity
</footer>
<script>
(function () {
  var sid = "__SID__";
  var statusUrl = "/api/file?filename=" + encodeURIComponent(
    "$HOME/.cache/biglinuxcleaner/" + sid + "/status.json");
  var logUrlBase = "execute$./tail_log.sh.html?session=" + encodeURIComponent(sid) + "&from=";
  var renderedLines = 0;
  var running = true;
  var inFlight = false;

  var TASK_LABELS = {
    orphans: "Pacotes orfaos",
    shortcuts: "Atalhos quebrados",
    steam: "Icones da Steam",
    flatpak_orphan: "Atalhos Flatpak",
    snap_orphan: "Atalhos Snap",
    cache: "Cache Flatpak/Snap",
    refresh: "Atualizar menu"
  };

  function el(id) { return document.getElementById(id); }

  function applyStatus(s) {
    var pct = s.total > 0 ? Math.round((s.done / s.total) * 100) : 0;
    el("progress-bar").style.width = pct + "%";
    el("progress-label").textContent = s.done + " de " + s.total + " tarefas";
    el("stat-tasks").textContent = s.done + "/" + s.total;
    el("stat-orphans").textContent = s.stats.orphans_removed;
    el("stat-shortcuts").textContent = s.stats.shortcuts_removed;
    el("stat-steam").textContent = s.stats.steam_fixed;

    var cur = s.current_task || "";
    if (cur && TASK_LABELS[cur]) cur = TASK_LABELS[cur];
    el("current-task").textContent = cur ? ("Tarefa: " + cur) : "Aguardando...";

    running = s.running;
    if (!running) {
      el("subtitle").textContent = "Limpeza finalizada";
      el("action-text").textContent = "Processo finalizado";
      el("spinner").style.display = "none";
    }
  }

  function fetchLog() {
    var url = logUrlBase + renderedLines;
    fetch(url).then(function (r) { return r.text(); }).then(function (txt) {
      var lines = txt.split("\n");
      var out = el("log-output");
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (!line) continue;
        var idx = line.indexOf("\t");
        var cls = idx >= 0 ? line.slice(0, idx) : "info";
        var msg = idx >= 0 ? line.slice(idx + 1) : line;
        var div = document.createElement("div");
        div.className = "log-" + cls;
        div.textContent = msg;
        out.appendChild(div);
        renderedLines++;
      }
      out.scrollTop = out.scrollHeight;
    }).catch(function () {});
  }

  function tick() {
    if (inFlight) return;
    inFlight = true;
    fetch(statusUrl).then(function (r) { return r.json(); }).then(function (s) {
      applyStatus(s);
      fetchLog();
    }).catch(function () {}).then(function () {
      inFlight = false;
      if (running) setTimeout(tick, 800);
    });
  }

  tick();
})();
</script>
</body>
</html>
PROGRESS_HTML
)"
    page="${page//__SID__/$sid}"
    page="${page//__DE_BADGE__/$de_badge}"
    printf '%s\n' "$page"
}

# ═══════════════════════════════════════════
# MODO B — Worker (--worker SESSION_DIR)
# ═══════════════════════════════════════════

main_worker() {
    set -Eeuo pipefail

    local session_dir="${1:-}"
    [[ -n "$session_dir" && -d "$session_dir" ]] || exit 1

    BLC_STATUS_FILE="$session_dir/status.json"
    BLC_LOG_FILE="$session_dir/log.txt"

    # Le e valida tasks.env
    local tasks_file="$session_dir/tasks.env"
    [[ -f "$tasks_file" ]] || exit 1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[A-Z_]+=[01]$ ]] || continue
        # shellcheck disable=SC1090
        source <(printf '%s\n' "$line") || true
    done < "$tasks_file"

    # Contadores
    SCANNED=0; INVALID=0; REMOVED=0; FAILED=0
    STEAM_FIXED=0; ORPHANS_REMOVED=0; FLATPAK_CLEANED=0; SNAP_CLEANED=0

    # Total de tarefas
    local BLC_TOTAL=0
    if [[ "${TASK_ORPHANS:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    if [[ "${TASK_SHORTCUTS:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    if [[ "${TASK_STEAM:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    if [[ "${TASK_FLATPAK_ORPHAN:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    if [[ "${TASK_SNAP_ORPHAN:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    if [[ "${TASK_CACHE:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    if [[ "${TASK_REFRESH:-0}" == "1" ]]; then BLC_TOTAL=$((BLC_TOTAL + 1)); fi
    local BLC_DONE=0

    # Trap: morte inesperada nao deixa a UI pendurada
    trap 'blc_worker_died' ERR
    blc_worker_died() {
        blc_write_status false "erro inesperado" "${BLC_DONE:-0}" "${BLC_TOTAL:-0}" || true
    }

    # Status inicial
    blc_write_status true "" 0 "$BLC_TOTAL"

    # Prepara sudo (mantem comportamento original)
    prepare_sudo

    # ─── Orfaos ───
    if [[ "${TASK_ORPHANS:-0}" == "1" ]]; then
        blc_write_status true "orphans" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_orphans
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # ─── Atalhos quebrados ───
    if [[ "${TASK_SHORTCUTS:-0}" == "1" ]]; then
        blc_write_status true "shortcuts" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_shortcuts
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # ─── Icones Steam ───
    if [[ "${TASK_STEAM:-0}" == "1" ]]; then
        blc_write_status true "steam" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_steam
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # ─── Flatpak orfaos ───
    if [[ "${TASK_FLATPAK_ORPHAN:-0}" == "1" ]]; then
        blc_write_status true "flatpak_orphan" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_flatpak_orphan
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # ─── Snap orfaos ───
    if [[ "${TASK_SNAP_ORPHAN:-0}" == "1" ]]; then
        blc_write_status true "snap_orphan" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_snap_orphan
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # ─── Cache ───
    if [[ "${TASK_CACHE:-0}" == "1" ]]; then
        blc_write_status true "cache" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_cache
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # ─── Refresh do DE ───
    if [[ "${TASK_REFRESH:-0}" == "1" ]]; then
        blc_write_status true "refresh" "$BLC_DONE" "$BLC_TOTAL"
        set +e
        run_refresh
        set -e
        BLC_DONE=$((BLC_DONE + 1))
        blc_write_status true "" "$BLC_DONE" "$BLC_TOTAL"
    fi

    # Finaliza
    blc_write_status false "" "$BLC_DONE" "$BLC_TOTAL"
}

# ═══════════════════════════════════════════
# DESPACHTE DE MODO
# ═══════════════════════════════════════════

if [[ "${1:-}" == "--worker" ]]; then
    main_worker "${2:-}"
else
    main_post
fi
