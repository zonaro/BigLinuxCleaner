#!/bin/bash
##
# @file start_cleaner.sh
# @brief Inicia o cleaner.sh em segundo plano e retorna imediatamente.
#        A saída ANSI é convertida para divs HTML e acumulada em LOG_FILE.
#        BigBashView executa este script; a resposta "ok" encerra a requisição.
##

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly CLEANER="${SCRIPT_DIR}/../cleaner.sh"
readonly LOG_FILE="/tmp/biglinux_cleaner_gui.log"
readonly STATUS_FILE="/tmp/biglinux_cleaner_gui.status"

# Remove arquivos de estado de execuções anteriores e marca como em andamento
# (feito ANTES do subshell para evitar que o primeiro poll retorne IDLE)
rm -f "${LOG_FILE}" "${STATUS_FILE}"
echo "RUNNING" > "${STATUS_FILE}"

##
# @brief Pré-autentica sudo via ksshaskpass (dialog gráfico KDE) para que os
#        comandos sudo dentro do cleaner.sh funcionem sem TTY no subprocesso.
#        Testa candidatos em ordem: variável de ambiente → caminhos comuns.
#        É seguro falhar (|| true): o cleaner.sh reportará o erro no log.
##
pre_auth_sudo() {
    # Já autenticado? Não precisa de dialog.
    sudo -n true 2>/dev/null && return 0

    # Localiza o agente askpass: prioriza var de ambiente, depois caminhos fixos.
    local askpass="${SUDO_ASKPASS:-}"
    if [[ -z "${askpass}" ]]; then
        for candidate in \
            /usr/bin/ksshaskpass \
            /usr/sbin/ksshaskpass \
            /usr/lib/ksshaskpass \
            /usr/lib/ssh/ksshaskpass \
            /usr/lib/x86_64-linux-gnu/ssh/ksshaskpass; do
            [[ -x "${candidate}" ]] && askpass="${candidate}" && break
        done
    fi

    [[ -z "${askpass}" ]] && return 1

    SUDO_ASKPASS="${askpass}" sudo -A -v 2>/dev/null
}

pre_auth_sudo || true   # falha silenciosa; cleaner.sh reporta erro no log

##
# @brief Converte uma linha de texto bruto (com possíveis códigos ANSI)
#        em um elemento <div> HTML com classe de cor correspondente.
# @param $1  Linha de saída do cleaner.sh.
##
line_to_html() {
    local raw="$1"

    # Remove sequências de escape ANSI (ex: \033[0;32m)
    local plain
    plain="$(printf '%s' "${raw}" | sed 's/\x1b\[[0-9;]*m//g')"

    # Ignora linhas totalmente vazias após strip ANSI
    [[ -z "${plain}" ]] && return

    # Escapa caracteres especiais HTML no conteúdo
    plain="${plain//&/&amp;}"
    plain="${plain//</&lt;}"
    plain="${plain//>/&gt;}"

    # Determina classe CSS pelo prefixo de nível de log do cleaner.sh
    local css="line-default"
    if   [[ "${plain}" == *"[INFO]"* ]]; then css="line-info"
    elif [[ "${plain}" == *"[OK]"*   ]]; then css="line-ok"
    elif [[ "${plain}" == *"[WARN]"* ]]; then css="line-warn"
    elif [[ "${plain}" == *"[ERRO]"* ]]; then css="line-err"
    fi

    printf '<div class="%s">%s</div>\n' "${css}" "${plain}"
}

# ── Processo em segundo plano ─────────────────────────────────────────────────
# Subshell lança o cleaner e converte cada linha para HTML no log.
# O polling do JS (poll_output.sh) lê este arquivo incrementalmente.
# disown $! garante que o subshell não receba SIGHUP quando start_cleaner.sh
# (o processo pai) encerrar — essencial para BBV que usa communicate().
(
    bash "${CLEANER}" 2>&1 | \
    while IFS= read -r line; do
        line_to_html "${line}"
    done >> "${LOG_FILE}"

    echo "DONE" > "${STATUS_FILE}"
) &
disown $!

# Resposta mínima para encerrar a requisição BBV (ignorada pelo JS)
echo "ok"
