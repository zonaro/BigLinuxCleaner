#!/bin/bash
##
# @file index.sh
# @brief BigLinux Cleaner GUI — Página principal gerada por Bash.
#        Executado pelo BigBashView; produz o HTML completo da interface.
#
# Arquitetura de polling:
#   1. Botão dispara fetch → start_cleaner.sh (lança cleaner.sh em background)
#   2. JS inicia setInterval(500ms) → poll_output.sh (lê novas linhas do log)
#   3. Ao receber status DONE, interrompe o polling e reabilita o botão.
##

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat << EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BigLinux Cleaner</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Noto Sans', 'Segoe UI', Ubuntu, sans-serif;
            background: #1e1e2e;
            color: #cdd6f4;
            display: flex;
            flex-direction: column;
            height: 100vh;
            padding: 20px 24px;
            gap: 16px;
            overflow: hidden;
        }

        /* ── Cabeçalho ──────────────────────────────────────────── */
        header {
            display: flex;
            align-items: center;
            gap: 14px;
            padding-bottom: 14px;
            border-bottom: 1px solid #313244;
            flex-shrink: 0;
        }
        .hdr-icon  { font-size: 2.2rem; line-height: 1; }
        .hdr-title {
            font-size: 1.35rem;
            font-weight: 700;
            color: #cba6f7;
            letter-spacing: -0.01em;
        }
        .hdr-sub {
            font-size: 0.78rem;
            color: #6c7086;
            margin-top: 3px;
        }

        /* ── Área de log ────────────────────────────────────────── */
        #output {
            flex: 1;
            min-height: 0;
            background: #181825;
            border: 1px solid #313244;
            border-radius: 10px;
            padding: 14px 18px;
            font-family: 'JetBrains Mono', 'Cascadia Mono', 'DejaVu Sans Mono', monospace;
            font-size: 0.8rem;
            line-height: 1.65;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-word;
        }

        .empty-hint {
            display: block;
            color: #45475a;
            font-style: italic;
            text-align: center;
            font-size: 0.88rem;
            padding-top: 80px;
            font-family: 'Noto Sans', sans-serif;
            white-space: normal;
        }

        /* Classes de nível de log */
        .line-info    { color: #89b4fa; display: block; }
        .line-ok      { color: #a6e3a1; display: block; }
        .line-warn    { color: #f9e2af; display: block; }
        .line-err     { color: #f38ba8; display: block; }
        .line-default { color: #cdd6f4; display: block; }

        /* ── Rodapé / Controles ──────────────────────────────────── */
        .footer {
            display: flex;
            align-items: center;
            gap: 14px;
            flex-shrink: 0;
        }

        #btn-clean {
            background: #cba6f7;
            color: #1e1e2e;
            border: none;
            border-radius: 8px;
            padding: 10px 26px;
            font-size: 0.9rem;
            font-weight: 700;
            cursor: pointer;
            letter-spacing: 0.02em;
            transition: background 0.15s, transform 0.1s, box-shadow 0.15s;
            box-shadow: 0 2px 8px rgba(203, 166, 247, 0.3);
            white-space: nowrap;
        }
        #btn-clean:hover:not(:disabled) {
            background: #d8b4fe;
            transform: translateY(-1px);
            box-shadow: 0 4px 14px rgba(203, 166, 247, 0.4);
        }
        #btn-clean:active:not(:disabled) { transform: translateY(0); }
        #btn-clean:disabled {
            background: #313244;
            color: #585b70;
            cursor: not-allowed;
            box-shadow: none;
        }

        #status-bar {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.82rem;
            color: #6c7086;
        }
        .spinner {
            width: 13px; height: 13px;
            border: 2px solid #313244;
            border-top-color: #cba6f7;
            border-radius: 50%;
            animation: spin 0.75s linear infinite;
            flex-shrink: 0;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .st-done  { color: #a6e3a1; }
        .st-error { color: #f38ba8; }
    </style>
</head>
<body>

<header>
    <span class="hdr-icon">🧹</span>
    <div>
        <div class="hdr-title">BigLinux Cleaner</div>
        <div class="hdr-sub">Remove atalhos órfãos, pacotes e cache do sistema</div>
    </div>
</header>

<div id="output">
    <span class="empty-hint">Pressione "Limpar Sistema" para iniciar a varredura...</span>
</div>

<div class="footer">
    <button id="btn-clean" onclick="startCleaning()">🚀 Limpar Sistema</button>
    <div id="status-bar"></div>
</div>

<script>
    /* Diretório absoluto do gui/ — injetado pelo Bash ao gerar este HTML */
    var GUI_DIR   = '${SCRIPT_DIR}';
    var polling   = null;
    var byteOffset = 0;
    var pollCount  = 0;
    var MAX_POLLS  = 1200; /* timeout de 10 min × (500 ms/poll) */

    /** Inicia o processo de limpeza ao clicar no botão */
    function startCleaning() {
        var btn    = document.getElementById('btn-clean');
        var output = document.getElementById('output');

        btn.disabled  = true;
        byteOffset    = 0;
        pollCount     = 0;
        output.innerHTML = '';
        setStatus('running', 'Iniciando a limpeza...');

        /* Chama start_cleaner.sh via protocolo BBV execute\$ */
        fetch('/execute\$' + GUI_DIR + '/start_cleaner.sh')
            .then(function()  { beginPoll(); })
            .catch(function() { beginPoll(); });
    }

    /** Inicia o loop de polling após disparar o cleaner */
    function beginPoll() {
        setStatus('running', 'Executando limpeza do sistema...');
        polling = setInterval(pollOutput, 500);
    }

    /** Consulta poll_output.sh por novas linhas do log */
    function pollOutput() {
        pollCount++;
        if (pollCount > MAX_POLLS) {
            clearInterval(polling);
            setStatus('error', '⚠️ Tempo limite atingido (10 min).');
            document.getElementById('btn-clean').disabled = false;
            return;
        }

        fetch('/execute\$' + GUI_DIR + '/poll_output.sh?p_offset=' + byteOffset)
            .then(function(r)    { return r.text(); })
            .then(function(text) { handlePoll(text); })
            .catch(function()    { /* rede ocupada, tentará novamente */ });
    }

    /**
     * Processa a resposta de poll_output.sh.
     * Formato: "STATUS:NOVO_OFFSET\n<html content...>"
     */
    function handlePoll(text) {
        var nl = text.indexOf('\n');
        if (nl < 0) return;

        var header  = text.substring(0, nl);
        var content = text.substring(nl + 1);
        var sep     = header.indexOf(':');
        var status  = sep >= 0 ? header.substring(0, sep)               : header;
        var newOff  = sep >= 0 ? parseInt(header.substring(sep + 1), 10) : NaN;

        /* Adiciona novas linhas ao log, removendo hint inicial se presente */
        if (content.trim().length > 0) {
            var out  = document.getElementById('output');
            var hint = out.querySelector('.empty-hint');
            if (hint) hint.remove();
            out.innerHTML += content;
            out.scrollTop  = out.scrollHeight;
        }

        if (!isNaN(newOff)) byteOffset = newOff;

        /* Finaliza quando o cleaner terminar */
        if (status === 'DONE') {
            clearInterval(polling);
            polling = null;
            setStatus('done', '✅ Limpeza concluída com sucesso!');
            document.getElementById('btn-clean').disabled = false;
        }
    }

    /** Atualiza a barra de status com spinner ou mensagem colorida */
    function setStatus(type, msg) {
        var bar = document.getElementById('status-bar');
        if (type === 'running') {
            bar.innerHTML = '<div class="spinner"></div>' + msg;
        } else {
            bar.innerHTML = '<span class="st-' + type + '">' + msg + '</span>';
        }
    }
</script>

</body>
</html>
EOF
