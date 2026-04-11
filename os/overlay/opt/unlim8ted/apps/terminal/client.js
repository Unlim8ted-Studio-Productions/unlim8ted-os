window.Unlim8tedAppClients = window.Unlim8tedAppClients || {};
window.Unlim8tedAppClients.terminal = (() => {
    let currentCtx = null;

    function lineMarkup(line) {
        const kind = line?.kind || 'output';
        const color = {
            command: '#62ffb0',
            error: '#ff8d8d',
            status: '#ffd36a',
            system: '#8cd3ff',
            output: '#d7ffe9'
        }[kind] || '#d7ffe9';
        return `<div style="color:${color};margin:0 0 6px;">${currentCtx.escapeHtml(line?.text || '')}</div>`;
    }

    function render(payload, ctx) {
        currentCtx = ctx;
        currentCtx.payload = payload || {};

        const cwd = ctx.appBody.querySelector('#terminalCwd');
        const output = ctx.appBody.querySelector('#terminalOutput');
        const form = ctx.appBody.querySelector('#terminalForm');
        const input = ctx.appBody.querySelector('#terminalCommand');
        const clear = ctx.appBody.querySelector('#terminalClear');

        if (cwd) cwd.textContent = payload?.cwd || '/';
        if (output) {
            output.innerHTML = (payload?.lines || []).map(lineMarkup).join('');
            output.scrollTop = output.scrollHeight;
        }

        form?.addEventListener('submit', async (event) => {
            event.preventDefault();
            const command = input?.value || '';
            if (!command.trim()) return;
            if (input) input.value = '';
            const response = await ctx.requestJson('/api/apps/terminal/action', {
                method: 'POST',
                body: JSON.stringify({ action: 'run', payload: { command } })
            });
            if (response?.app) render(response.app, ctx);
        }, { once: true });

        clear?.addEventListener('click', async () => {
            const response = await ctx.requestJson('/api/apps/terminal/action', {
                method: 'POST',
                body: JSON.stringify({ action: 'clear', payload: {} })
            });
            if (response?.app) render(response.app, ctx);
        }, { once: true });

        setTimeout(() => input?.focus(), 50);
    }

    return { render };
})();
