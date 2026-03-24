#!/bin/bash
##
# @file launch.sh
# @brief Lança a GUI do BigLinux Cleaner usando o BigBashView.
# @usage ./launch.sh
##

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Garante que todos os scripts da GUI têm permissão de execução
chmod +x \
    "${SCRIPT_DIR}/launch.sh" \
    "${SCRIPT_DIR}/gui/index.sh" \
    "${SCRIPT_DIR}/gui/start_cleaner.sh" \
    "${SCRIPT_DIR}/gui/poll_output.sh" 2>/dev/null || true

if ! command -v bigbashview &>/dev/null; then
    echo "Erro: bigbashview não encontrado no PATH." >&2
    echo "Instale o BigBashView: https://github.com/biglinux/bigbashview" >&2
    exit 1
fi

exec bigbashview \
    -s 920x700 \
    -n 'BigLinux Cleaner' \
    -p 'biglinux-cleaner' \
    'execute$'"${SCRIPT_DIR}/gui/index.sh"
