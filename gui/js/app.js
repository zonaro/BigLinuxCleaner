/* BigLinuxCleaner GUI — Interações da interface */

document.addEventListener('DOMContentLoaded', function () {
    initTaskCards();
    initSelectAll();
    initConfirmDialog();
});

/* ─── Task Card Selection ─── */
function initTaskCards() {
    document.querySelectorAll('.task-card').forEach(function (card) {
        card.addEventListener('click', function (e) {
            // Evita toggle duplo se clicou no checkbox diretamente
            if (e.target.tagName === 'INPUT') return;

            var cb = card.querySelector('input[type="checkbox"]');
            cb.checked = !cb.checked;
            card.classList.toggle('selected', cb.checked);
            updateTaskCount();
        });

        // Sincroniza estado inicial
        var cb = card.querySelector('input[type="checkbox"]');
        if (cb.checked) {
            card.classList.add('selected');
        }
    });
    updateTaskCount();
}

/* ─── Select All / Deselect All ─── */
function initSelectAll() {
    var btn = document.getElementById('btn-select-all');
    if (!btn) return;

    btn.addEventListener('click', function () {
        var cards = document.querySelectorAll('.task-card');
        var allSelected = Array.from(cards).every(function (c) {
            return c.querySelector('input[type="checkbox"]').checked;
        });

        cards.forEach(function (card) {
            var cb = card.querySelector('input[type="checkbox"]');
            cb.checked = !allSelected;
            card.classList.toggle('selected', cb.checked);
        });

        btn.textContent = allSelected ? 'Selecionar todas' : 'Desselecionar todas';
        updateTaskCount();
    });
}

/* ─── Task Count Badge ─── */
function updateTaskCount() {
    var count = document.querySelectorAll('.task-card.selected').length;
    var total = document.querySelectorAll('.task-card').length;
    var el = document.getElementById('task-count');
    if (el) {
        el.innerHTML = '<strong>' + count + '</strong> de ' + total + ' tarefas selecionadas';
    }

    var runBtn = document.getElementById('btn-run');
    if (runBtn) {
        runBtn.disabled = count === 0;
    }
}

/* ─── Confirm Dialog ─── */
function initConfirmDialog() {
    var overlay = document.getElementById('confirm-overlay');
    if (!overlay) return;

    var btnYes = document.getElementById('confirm-yes');
    var btnNo = document.getElementById('confirm-no');

    if (btnNo) {
        btnNo.addEventListener('click', function () {
            overlay.classList.remove('active');
        });
    }

    // Fecha ao clicar fora
    overlay.addEventListener('click', function (e) {
        if (e.target === overlay) {
            overlay.classList.remove('active');
        }
    });
}

function showConfirm() {
    var overlay = document.getElementById('confirm-overlay');
    if (overlay) {
        overlay.classList.add('active');
    }
}

function hideConfirm() {
    var overlay = document.getElementById('confirm-overlay');
    if (overlay) {
        overlay.classList.remove('active');
    }
}

/* ─── Loading State ─── */
function setLoading(isLoading) {
    var btn = document.getElementById('btn-run');
    if (!btn) return;

    if (isLoading) {
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner"></span> Executando...';
    } else {
        btn.disabled = false;
        btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="13 17 18 12 13 7"></polyline><polyline points="6 17 11 12 6 7"></polyline></svg> Iniciar Limpeza';
    }
}

/* ─── Form Submit Handler ─── */
function handleSubmit(form) {
    var selected = document.querySelectorAll('.task-card.selected input[type="checkbox"]');
    if (selected.length === 0) {
        return false;
    }

    setLoading(true);
    hideConfirm();
    return true;
}

/* ─── Scroll to Bottom (log output) ─── */
function scrollLogToBottom() {
    var log = document.getElementById('log-output');
    if (log) {
        log.scrollTop = log.scrollHeight;
    }
}
