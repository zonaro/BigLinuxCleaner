#!/bin/bash
##
# @file poll_output.sh
# @brief Retorna novas linhas do log HTML desde o byte offset informado.
#        Recebe $p_offset via variável de ambiente injetada pelo BigBashView
#        a partir do query string "?p_offset=N" da requisição JS.
#
# Formato de resposta (stdout):
#   Linha 1 → "STATUS:NOVO_OFFSET"   (STATUS = RUNNING | DONE | IDLE)
#   Restante → Conteúdo HTML novo desde o offset anterior (pode estar vazio)
##

readonly LOG_FILE="/tmp/biglinux_cleaner_gui.log"
readonly STATUS_FILE="/tmp/biglinux_cleaner_gui.status"

# ── Validação de segurança: p_offset deve ser inteiro não-negativo ─────────────
if [[ "${p_offset:-}" =~ ^[0-9]+$ ]]; then
    offset="${p_offset}"
else
    offset=0
fi

# ── Status atual do processo de limpeza ───────────────────────────────────────
if [[ ! -f "${STATUS_FILE}" ]]; then
    run_status="IDLE"
else
    run_status="$(cat "${STATUS_FILE}" 2>/dev/null)" || run_status="UNKNOWN"
fi

# ── Tamanho atual do log em bytes (novo offset a reportar) ────────────────────
if [[ -f "${LOG_FILE}" ]]; then
    file_size="$(wc -c < "${LOG_FILE}" 2>/dev/null)" || file_size=0
else
    file_size=0
fi

# ── Linha de cabeçalho: STATUS:NOVO_OFFSET ────────────────────────────────────
printf '%s:%s\n' "${run_status}" "${file_size}"

# ── Conteúdo novo desde o byte offset anterior ────────────────────────────────
# tail -c +N é 1-indexado: +1 = byte 1 (início do arquivo)
if (( file_size > offset )); then
    tail -c "+$((offset + 1))" "${LOG_FILE}"
fi
