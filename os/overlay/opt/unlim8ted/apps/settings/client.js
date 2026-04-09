window.Unlim8tedAppClients = window.Unlim8tedAppClients || {};
window.Unlim8tedAppClients.settings = (() => {
    let currentCtx = null;

    function settingsState(payload = {}) {
        return payload.settings || currentCtx?.payload?.settings || {
            brightness: 68,
            idle_timeout_sec: 45,
            sleeping: false,
            toggles: [],
            badges: [],
            device: []
        };
    }

    async function sendAction(action, value) {
        if (!currentCtx) return;
        const response = await currentCtx.requestJson('/api/apps/settings/action', {
            method: 'POST',
            body: JSON.stringify({ action, payload: { value } })
        });
        if (response?.app) {
            currentCtx.payload = response.app;
            render(response.app, currentCtx);
        }
        if (response?.system) {
            currentCtx.syncSystemState?.();
        }
    }

    function profileMarkup(owner, sleeping) {
        const initial = String(owner || 'U').trim().charAt(0).toUpperCase() || 'U';
        return `
            <div class="settings-profile">
                <div class="settings-avatar">${initial}</div>
                <div>
                    <div class="settings-kicker">Owner</div>
                    <div class="settings-profile-name">${currentCtx.escapeHtml(owner || 'Unknown Owner')}</div>
                    <div class="settings-profile-copy">${sleeping ? 'Display is sleeping right now. Wake the device to continue.' : 'Local device controls and status update here in real time.'}</div>
                </div>
            </div>
        `;
    }

    function deviceMarkup(device) {
        return device.map((item) => `
            <div class="settings-detail-row">
                <div>
                    <div class="settings-detail-label">${currentCtx.escapeHtml(item.label || '')}</div>
                    <div class="settings-row-title">${currentCtx.escapeHtml(item.value || '')}</div>
                </div>
                
            </div>
        `).join('');
    }

    function togglesMarkup(toggles) {
        return toggles.map((item) => `
            <button type="button" class="settings-toggle-row ${item.enabled ? 'active' : ''}" data-settings-toggle="${currentCtx.escapeHtml(item.id)}">
                <div>
                    <div class="settings-row-title">${currentCtx.escapeHtml(item.label || item.id || '')}</div>
                    <div class="settings-row-copy">${item.enabled ? 'Enabled and ready to use.' : 'Currently turned off.'}</div>
                </div>
                <div class="settings-toggle-pill"></div>
            </button>
        `).join('');
    }

    function displayMarkup(brightness, idleTimeout) {
        const timeoutOptions = [15, 30, 60, 120, 300, 600];
        return `
            <div class="settings-display-stack">
                <div class="settings-display-block">
                    <div class="settings-row-overline">Brightness</div>
                    <div class="settings-row-title">Panel output</div>
                    <div class="settings-row-copy">Adjust screen luminance without leaving the app.</div>
                    <div class="settings-slider-row">
                        <input class="settings-slider" id="settingsBrightnessRange" type="range" min="5" max="100" value="${brightness}" />
                        <div class="settings-slider-value" id="settingsBrightnessValue">${brightness}%</div>
                    </div>
                </div>
                <div class="settings-display-block">
                    <div class="settings-row-overline">Idle timeout</div>
                    <div class="settings-row-title">Auto-sleep timer</div>
                    <div class="settings-row-copy">Choose how long the device waits before it fades to sleep.</div>
                    <div class="settings-timeout-grid">
                        ${timeoutOptions.map((seconds) => `
                            <button type="button" class="settings-chip ${seconds === idleTimeout ? 'active' : ''}" data-timeout-value="${seconds}">${seconds}s</button>
                        `).join('')}
                    </div>
                </div>
            </div>
        `;
    }

    function badgesMarkup(badges) {
        if (!badges.length) {
            return '<div class="settings-empty">No apps are asking for attention right now. Badge counts will appear here when activity stacks up.</div>';
        }
        return badges.map((item) => `
            <div class="settings-badge-row">
                <div>
                    <div class="settings-badge-meta">${currentCtx.escapeHtml(item.id || '')}</div>
                    <div class="settings-row-title">Notification activity</div>
                </div>
                <div class="settings-badge-count">${currentCtx.escapeHtml(String(item.count || 0))}</div>
            </div>
        `).join('');
    }

    function bindEvents(state) {
        currentCtx.appBody.querySelectorAll('[data-settings-toggle]').forEach((button) => {
            button.addEventListener('click', () => sendAction('toggle_connectivity', button.dataset.settingsToggle || ''));
        });

        currentCtx.appBody.querySelectorAll('[data-timeout-value]').forEach((button) => {
            button.addEventListener('click', () => sendAction('set_idle_timeout', button.dataset.timeoutValue || ''));
        });

        const range = currentCtx.appBody.querySelector('#settingsBrightnessRange');
        const value = currentCtx.appBody.querySelector('#settingsBrightnessValue');
        range?.addEventListener('input', () => {
            if (value) value.textContent = `${range.value}%`;
        });
        range?.addEventListener('change', () => {
            sendAction('set_brightness', range.value || String(state.brightness || 68));
        });
    }

    async function render(payload, ctx) {
        currentCtx = ctx;
        currentCtx.payload = payload || {};
        const state = settingsState(payload || {});
        const owner = payload?.owner || 'Owner';

        const ownerLine = currentCtx.appBody.querySelector('#settingsOwnerLine');
        const sleepState = currentCtx.appBody.querySelector('#settingsSleepState');
        const profile = currentCtx.appBody.querySelector('#settingsProfileCard');
        const stats = currentCtx.appBody.querySelector('#settingsDeviceStats');
        const toggles = currentCtx.appBody.querySelector('#settingsToggleGroup');
        const display = currentCtx.appBody.querySelector('#settingsDisplayGroup');
        const badges = currentCtx.appBody.querySelector('#settingsBadgesGroup');

        if (ownerLine) ownerLine.textContent = `${owner}'s device, controls, and current system state.`;
        if (sleepState) sleepState.textContent = state.sleeping ? 'Sleeping' : 'Awake';
        if (profile) profile.innerHTML = profileMarkup(owner, state.sleeping);
        if (stats) stats.innerHTML = deviceMarkup(state.device || []);
        if (toggles) toggles.innerHTML = togglesMarkup(state.toggles || []);
        if (display) display.innerHTML = displayMarkup(state.brightness || 68, state.idle_timeout_sec || 45);
        if (badges) badges.innerHTML = badgesMarkup(state.badges || []);

        bindEvents(state);
    }

    return { render };
})();


