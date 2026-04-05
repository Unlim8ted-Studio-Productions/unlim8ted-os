window.Unlim8tedAppClients = window.Unlim8tedAppClients || {};
window.Unlim8tedAppClients.files = (() => {
    let currentCtx = null;

    async function sendAction(action, payload = {}) {
        if (!currentCtx) return null;
        const response = await currentCtx.requestJson('/api/apps/files/action', {
            method: 'POST',
            body: JSON.stringify({ action, payload })
        });
        if (response?.app) {
            currentCtx.payload = response.app;
            render(response.app, currentCtx);
            currentCtx.rememberRecentApp?.('files', response.app);
        }
        if (response?.system) currentCtx.syncSystemState?.();
        return response;
    }

    function entryIcon(kind) {
        if (kind === 'dir') return '📁';
        if (kind === 'nav') return '↩';
        return '📄';
    }

    function entriesMarkup(entries) {
        if (!entries.length) {
            return '<div class="files-empty">This folder is empty. Create a file or folder to get started.</div>';
        }
        return entries.map((entry) => `
            <button type="button" class="files-entry ${entry.selected ? 'selected' : ''}" data-files-action="${currentCtx.escapeHtml(entry.action || '')}" data-files-value="${currentCtx.escapeHtml(entry.value || '')}">
                <div class="files-entry-icon">${entryIcon(entry.kind)}</div>
                <div class="files-entry-main">
                    <div class="files-entry-name">${currentCtx.escapeHtml(entry.name || '')}</div>
                    <div class="files-entry-meta">${currentCtx.escapeHtml(entry.meta || entry.description || '')}</div>
                </div>
                <div class="files-entry-arrow">›</div>
            </button>
        `).join('');
    }

    function detailRowsMarkup(rows) {
        if (!rows?.length) return '<div class="files-empty">No item selected.</div>';
        return rows.map((row) => `
            <div class="files-detail-row">
                <div class="files-detail-label">${currentCtx.escapeHtml(row.label || '')}</div>
                <div class="files-detail-value">${currentCtx.escapeHtml(row.value || '')}</div>
            </div>
        `).join('');
    }

    function previewMarkup(preview) {
        const kind = preview?.kind || 'empty';
        if (kind === 'text') {
            return `
                <form class="files-editor" id="filesSaveForm">
                    <div class="files-form-title">Text Editor</div>
                    <textarea class="files-textarea files-editor-textarea" name="body">${currentCtx.escapeHtml(preview.body || '')}</textarea>
                    <div class="files-editor-actions">
                        <button class="files-submit" type="submit">Save File</button>
                    </div>
                </form>
            `;
        }
        if (kind === 'image') {
            return `
                <div class="files-image-wrap">
                    <img class="files-image-preview" src="${currentCtx.escapeHtml(preview.url || '')}" alt="${currentCtx.escapeHtml(preview.title || 'Preview')}" />
                </div>
            `;
        }
        return `
            <div class="files-preview-card">
                <div class="files-form-title">${currentCtx.escapeHtml(preview?.title || 'Preview')}</div>
                <div class="files-preview-copy">${currentCtx.escapeHtml(preview?.body || 'Nothing selected.')}</div>
            </div>
        `;
    }

    function bindEvents(payload) {
        currentCtx.appBody.querySelectorAll('[data-files-action]').forEach((button) => {
            button.addEventListener('click', () => {
                sendAction(button.dataset.filesAction || '', { value: button.dataset.filesValue || '' });
            });
        });

        currentCtx.appBody.querySelector('#filesCreateFileForm')?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            sendAction('create_file', {
                name: String(form.get('name') || ''),
                body: String(form.get('body') || '')
            });
            event.currentTarget.reset();
        });

        currentCtx.appBody.querySelector('#filesCreateFolderForm')?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            sendAction('create_folder', { name: String(form.get('name') || '') });
            event.currentTarget.reset();
        });

        currentCtx.appBody.querySelector('#filesRenameForm')?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            sendAction('rename_path', {
                value: payload?.selected_path || '',
                name: String(form.get('name') || '')
            });
        });

        currentCtx.appBody.querySelector('#filesDeleteBtn')?.addEventListener('click', () => {
            if (!payload?.selected_path) return;
            sendAction('delete_file', { value: payload.selected_path });
        });

        currentCtx.appBody.querySelector('#filesSaveForm')?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            sendAction('save_file', {
                value: payload?.selected_path || '',
                body: String(form.get('body') || '')
            });
        });
    }

    async function render(payload, ctx) {
        currentCtx = ctx;
        currentCtx.payload = payload || {};

        const pathLabel = currentCtx.appBody.querySelector('#filesPathLabel');
        const status = currentCtx.appBody.querySelector('#filesStatus');
        const list = currentCtx.appBody.querySelector('#filesEntryList');
        const detail = currentCtx.appBody.querySelector('#filesDetailList');
        const preview = currentCtx.appBody.querySelector('#filesPreviewPanel');
        const renameInput = currentCtx.appBody.querySelector('#filesRenameInput');
        const deleteBtn = currentCtx.appBody.querySelector('#filesDeleteBtn');

        if (pathLabel) pathLabel.textContent = payload?.path_label || 'Personal Storage';
        if (status) status.textContent = payload?.notice || payload?.subtitle || 'Manage your local files.';
        if (list) list.innerHTML = entriesMarkup(payload?.entries || []);
        if (detail) detail.innerHTML = detailRowsMarkup(payload?.details || []);
        if (preview) preview.innerHTML = previewMarkup(payload?.preview || {});
        if (renameInput) renameInput.value = payload?.selected_name || '';
        if (deleteBtn) deleteBtn.disabled = !payload?.selected_path;

        bindEvents(payload || {});
    }

    return { render };
})();
