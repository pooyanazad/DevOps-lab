// State
let services = [];
let containers = [];
let volumes = [];
let terminal = null;
let ws = null;
let fitAddon = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupNavigation();
    refreshData();
    setInterval(refreshData, 10000); // Auto-refresh every 10 seconds
});

// Navigation
function setupNavigation() {
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const view = item.dataset.view;
            switchView(view);
        });
    });
}

function switchView(viewName) {
    // Update nav
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.toggle('active', item.dataset.view === viewName);
    });

    // Update views
    document.querySelectorAll('.view').forEach(view => {
        view.classList.remove('active');
    });
    document.getElementById(`${viewName}-view`).classList.add('active');

    // Update title
    const titles = {
        services: 'Services',
        terminal: 'Terminal',
        volumes: 'Volumes'
    };
    document.getElementById('page-title').textContent = titles[viewName];

    // Load data for specific views
    if (viewName === 'terminal') {
        loadContainersForTerminal();
        initTerminal();
    } else if (viewName === 'volumes') {
        loadVolumes();
    }
}

// Data Loading
async function refreshData() {
    await Promise.all([
        loadServices(),
        loadContainers()
    ]);
}

async function loadServices() {
    try {
        const response = await fetch('/api/services');
        services = await response.json();
        renderServices();
        updateContainerCount();
    } catch (error) {
        console.error('Error loading services:', error);
        showToast('Failed to load services', 'error');
    }
}

async function loadContainers() {
    try {
        const response = await fetch('/api/containers');
        containers = await response.json();
    } catch (error) {
        console.error('Error loading containers:', error);
    }
}

async function loadVolumes() {
    try {
        const response = await fetch('/api/volumes');
        volumes = await response.json();
        renderVolumes();
    } catch (error) {
        console.error('Error loading volumes:', error);
        showToast('Failed to load volumes', 'error');
    }
}

async function loadContainersForTerminal() {
    const select = document.getElementById('container-select');
    select.innerHTML = '<option value="">Select a container...</option>';

    containers.forEach(container => {
        if (container.status === 'running') {
            const option = document.createElement('option');
            option.value = container.name;
            option.textContent = container.name.replace('devopslab-', '');
            select.appendChild(option);
        }
    });
}

// Rendering
function renderServices() {
    const grid = document.getElementById('services-grid');

    // Group services by category
    const grouped = {};
    services.forEach(service => {
        const cat = service.category || 'other';
        if (!grouped[cat]) {
            grouped[cat] = {
                info: service.categoryInfo || { name: 'Other', icon: '📁', order: 99 },
                services: []
            };
        }
        grouped[cat].services.push(service);
    });

    // Sort categories by order
    const sortedCategories = Object.entries(grouped).sort((a, b) =>
        (a[1].info.order || 99) - (b[1].info.order || 99)
    );

    grid.innerHTML = sortedCategories.map(([catKey, category]) => `
        <div class="category-section">
            <div class="category-header">
                <span class="category-icon">${category.info.icon}</span>
                <span class="category-name">${category.info.name}</span>
                <span class="category-count">${category.services.length} service${category.services.length > 1 ? 's' : ''}</span>

            </div>
            <div class="category-services">
                ${category.services.map(service => `
                    <div class="service-card" data-service="${service.id}">
                        <div class="service-header">
                            <div class="service-info">
                                <div class="service-icon">${service.icon}</div>
                                <div>
                                    <div class="service-name">${service.name}</div>
                                    <div class="service-description">${service.description}</div>
                                </div>
                            </div>
                            <div class="service-status ${service.status}">
                                <span class="service-status-dot"></span>
                                ${service.status}
                            </div>
                        </div>
                        <div class="service-actions">
                            ${service.url ? `
                                <a href="${service.url}" target="_blank" class="btn btn-primary btn-sm">
                                    <span>🔗</span> Open
                                </a>
                            ` : ''}
                            ${service.hasShell !== false ? `
                                <button class="btn btn-secondary btn-sm" onclick="openTerminal('${service.container}')">
                                    <span>💻</span> Terminal
                                </button>
                            ` : `
                                <button class="btn btn-secondary btn-sm" disabled title="No shell available">
                                    <span>🚫</span> No Shell
                                </button>
                            `}
                            ${service.id.includes('jenkins-agent') ? `
                                <button class="btn btn-${service.status === 'running' ? 'warning' : 'success'} btn-sm" 
                                        onclick="toggleAgent('${service.container}')"
                                        title="${service.status === 'running' ? 'Stop' : 'Start'} agent">
                                    <span>${service.status === 'running' ? '⏹️' : '▶️'}</span> 
                                    ${service.status === 'running' ? 'Stop' : 'Start'}
                                </button>
                            ` : ''}
                            ${service.volumes && service.volumes.length > 0 ? `
                                <button class="btn btn-danger btn-sm" onclick="confirmCleanup('${service.id}', '${service.name}')">
                                    <span>🗑️</span> Cleanup
                                </button>
                            ` : ''}
                        </div>
                    </div>
                `).join('')}
            </div>
        </div>
    `).join('');
}

// Toggle Jenkins Agent
async function toggleAgent(containerName) {
    try {
        const service = services.find(s => s.container === containerName);
        const action = service?.status === 'running' ? 'stop' : 'start';

        showToast(`${action === 'start' ? 'Starting' : 'Stopping'} ${containerName}...`, 'info');

        const response = await fetch(`/api/jenkins-agents/${action}/${containerName}`, {
            method: 'POST'
        });

        const result = await response.json();

        if (result.success) {
            showToast(result.message, 'success');
            await refreshData();
        } else {
            showToast(result.error || 'Operation failed', 'error');
        }
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function renderVolumes() {
    const list = document.getElementById('volumes-list');

    if (volumes.length === 0) {
        list.innerHTML = '<p style="color: var(--text-muted); text-align: center; padding: 40px;">No volumes found</p>';
        return;
    }

    list.innerHTML = volumes.map(volume => {
        const service = services.find(s => s.volumes.includes(volume.name));
        return `
            <div class="volume-item">
                <div class="volume-info">
                    <div class="volume-icon">💾</div>
                    <div>
                        <div class="volume-name">${volume.name}</div>
                        <div class="volume-driver">Driver: ${volume.driver} ${service ? `• ${service.name}` : ''}</div>
                    </div>
                </div>
                <button class="btn btn-danger btn-sm" onclick="confirmVolumeDelete('${volume.name}')">
                    <span>🗑️</span> Delete
                </button>
            </div>
        `;
    }).join('');
}

function updateContainerCount() {
    const running = services.filter(s => s.status === 'running').length;
    document.getElementById('container-count').textContent = `${running} running`;
}

// Terminal
function initTerminal() {
    if (terminal) return;

    const terminalEl = document.getElementById('terminal');
    terminal = new Terminal({
        cursorBlink: true,
        fontSize: 14,
        fontFamily: 'Menlo, Monaco, "Courier New", monospace',
        theme: {
            background: '#0d0d0d',
            foreground: '#ffffff',
            cursor: '#ffffff',
            selection: 'rgba(99, 102, 241, 0.3)'
        }
    });

    fitAddon = new FitAddon.FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.open(terminalEl);
    fitAddon.fit();

    terminal.writeln('\x1b[1;35m╔════════════════════════════════════════╗\x1b[0m');
    terminal.writeln('\x1b[1;35m║     DevOpsLab Terminal                 ║\x1b[0m');
    terminal.writeln('\x1b[1;35m╚════════════════════════════════════════╝\x1b[0m');
    terminal.writeln('');
    terminal.writeln('\x1b[33mSelect a container and click Connect\x1b[0m');

    window.addEventListener('resize', () => {
        if (fitAddon) fitAddon.fit();
    });
}

function connectTerminal() {
    const containerName = document.getElementById('container-select').value;
    if (!containerName) {
        showToast('Please select a container', 'warning');
        return;
    }

    disconnectTerminal();

    terminal.clear();
    terminal.writeln(`\x1b[32mConnecting to ${containerName}...\x1b[0m\n`);

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    ws = new WebSocket(`${protocol}//${window.location.host}/ws?container=${containerName}`);

    ws.onopen = () => {
        showToast(`Connected to ${containerName}`, 'success');
    };

    ws.onmessage = (event) => {
        terminal.write(event.data);
    };

    ws.onclose = () => {
        terminal.writeln('\n\x1b[31mConnection closed\x1b[0m');
    };

    ws.onerror = (error) => {
        terminal.writeln('\n\x1b[31mConnection error\x1b[0m');
        showToast('Connection failed', 'error');
    };

    terminal.onData(data => {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(data);
        }
    });
}

function disconnectTerminal() {
    if (ws) {
        ws.close();
        ws = null;
    }
}

function openTerminal(containerName) {
    switchView('terminal');
    document.getElementById('container-select').value = containerName;
    setTimeout(() => {
        connectTerminal();
    }, 300);
}

// Actions
async function containerAction(containerName, action) {
    try {
        const response = await fetch(`/api/containers/${containerName}/${action}`, {
            method: 'POST'
        });
        const data = await response.json();

        if (data.success) {
            showToast(data.message, 'success');
            await refreshData();
        } else {
            showToast(data.error, 'error');
        }
    } catch (error) {
        showToast('Action failed', 'error');
    }
}

function confirmCleanup(serviceId, serviceName) {
    showModal(
        'Cleanup Volume',
        `Are you sure you want to cleanup the volume for <strong>${serviceName}</strong>? This will delete all data and restart the service.`,
        async () => {
            try {
                const response = await fetch(`/api/volumes/${serviceId}/cleanup`, {
                    method: 'POST'
                });
                const data = await response.json();

                if (data.success) {
                    showToast(data.message, 'success');
                    await refreshData();
                } else {
                    showToast(data.error, 'error');
                }
            } catch (error) {
                showToast('Cleanup failed', 'error');
            }
            closeModal();
        }
    );
}

function confirmVolumeDelete(volumeName) {
    showModal(
        'Delete Volume',
        `Are you sure you want to delete the volume <strong>${volumeName}</strong>? This will permanently delete all data.`,
        async () => {
            try {
                // Stop related container first, then delete volume
                showToast('Deleting volume...', 'warning');
                // For now, just show a message
                showToast('Use the service cleanup button instead', 'warning');
            } catch (error) {
                showToast('Delete failed', 'error');
            }
            closeModal();
        }
    );
}

// Modal
function showModal(title, message, onConfirm) {
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-message').innerHTML = message;
    document.getElementById('modal-confirm').onclick = onConfirm;
    document.getElementById('modal').classList.add('active');
}

function closeModal() {
    document.getElementById('modal').classList.remove('active');
}

// Toast
function showToast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    const icons = {
        success: '✅',
        error: '❌',
        warning: '⚠️'
    };

    toast.innerHTML = `
        <span>${icons[type]}</span>
        <span>${message}</span>
    `;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(100px)';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// Close modal on outside click
document.getElementById('modal').addEventListener('click', (e) => {
    if (e.target.id === 'modal') {
        closeModal();
    }
});
