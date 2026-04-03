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
        }
        if (response?.system) {
            currentCtx.syncSystemState?.();
        }
        return response;
    }

    function entryIcon(kind) {
        if (kind === 'dir') return '📁';
        if (kind === 'nav') return '↩';
        return '📄';
    }

    function entryMeta(entry) {
        if (entry.kind === 'nav') return 'Navigate to the parent folder';
        if (entry.kind === 'dir') return 'Folder';
        return entry.description || 'Text preview available';
    }

    function entriesMarkup(entries) {
        if (!entries.length) {
            return '<div class="files-form"><div class="files-form-title">This folder is empty</div><div class="files-entry-meta">Create a file or folder to get started.</div></div>';
        }
        return entries.map((entry) => `
            <button type="button" class="files-entry" data-files-action="${currentCtx.escapeHtml(entry.action || '')}" data-files-value="${currentCtx.escapeHtml(entry.value || '')}">
                <div class="files-entry-icon">${entryIcon(entry.kind)}</div>
                <div>
                    <div class="files-entry-name">${currentCtx.escapeHtml(entry.name || '')}</div>
                    <div class="files-entry-meta">${currentCtx.escapeHtml(entryMeta(entry))}</div>
                </div>
                <div class="files-entry-arrow">›</div>
            </button>
        `).join('');
    }

    function bindEvents(payload) {
        currentCtx.appBody.querySelectorAll('[data-files-action]').forEach((button) => {
            button.addEventListener('click', () => {
                const action = button.dataset.filesAction || '';
                const value = button.dataset.filesValue || '';
                if (!action) return;
                sendAction(action, { value });
                const deleteInput = currentCtx.appBody.querySelector('#filesDeleteInput');
                if (deleteInput) deleteInput.value = value;
            });
        });

        const fileForm = currentCtx.appBody.querySelector('#filesCreateFileForm');
        fileForm?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(fileForm);
            sendAction('create_file', {
                name: String(form.get('name') || ''),
                body: String(form.get('body') || '')
            });
            fileForm.reset();
        });

        const folderForm = currentCtx.appBody.querySelector('#filesCreateFolderForm');
        folderForm?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(folderForm);
            sendAction('create_folder', {
                name: String(form.get('name') || '')
            });
            folderForm.reset();
        });

        const deleteForm = currentCtx.appBody.querySelector('#filesDeleteForm');
        deleteForm?.addEventListener('submit', (event) => {
            event.preventDefault();
            const form = new FormData(deleteForm);
            sendAction('delete_file', {
                value: String(form.get('value') || '')
            });
        });

        const deleteInput = currentCtx.appBody.querySelector('#filesDeleteInput');
        if (deleteInput && payload?.preview_path) deleteInput.value = payload.preview_path;
    }

    async function render(payload, ctx) {
        currentCtx = ctx;
        currentCtx.payload = payload || {};

        const pathLabel = currentCtx.appBody.querySelector('#filesPathLabel');
        const entryList = currentCtx.appBody.querySelector('#filesEntryList');
        const previewPath = currentCtx.appBody.querySelector('#filesPreviewPath');
        const previewText = currentCtx.appBody.querySelector('#filesPreviewText');

        if (pathLabel) pathLabel.textContent = payload?.path_label || payload?.root_label || 'Personal Storage';
        if (entryList) entryList.innerHTML = entriesMarkup(payload?.entries || []);
        if (previewPath) previewPath.textContent = payload?.preview_path || 'No file selected';
        if (previewText) previewText.textContent = payload?.preview || 'Select a text file to preview its contents.';

        bindEvents(payload || {});
    }

    return { render };
})();
