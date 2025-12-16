const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const Docker = require('dockerode');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws' });

const docker = new Docker({ socketPath: '/var/run/docker.sock' });

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Service configuration with categories
// shell: null = no shell, 'bash' = has bash, 'sh' = only has sh (busybox/alpine)
const services = [
    // CI/CD Category
    { id: 'jenkins', name: 'Jenkins', port: 9902, container: 'devopslab-jenkins', icon: '🔧', description: 'CI/CD Automation', volumes: ['devopslab_jenkins_home'], shell: 'bash', category: 'cicd' },
    { id: 'jenkins-agent-1', name: 'Jenkins Agent 1', port: null, container: 'devopslab-jenkins-agent-1', icon: '🤖', description: 'Ubuntu Build Agent', volumes: ['devopslab_jenkins_agent1_home'], shell: 'bash', category: 'cicd' },
    { id: 'jenkins-agent-2', name: 'Jenkins Agent 2', port: null, container: 'devopslab-jenkins-agent-2', icon: '🤖', description: 'Ubuntu Build Agent', volumes: ['devopslab_jenkins_agent2_home'], shell: 'bash', category: 'cicd' },
    // Source Control Category
    { id: 'gitea', name: 'Gitea', port: 9903, container: 'devopslab-gitea', icon: '📦', description: 'Git Repository', volumes: ['devopslab_gitea_data'], shell: 'bash', category: 'source' },
    { id: 'gitea-db', name: 'Gitea DB', port: null, container: 'devopslab-gitea-db', icon: '🗄️', description: 'PostgreSQL Database', volumes: ['devopslab_gitea_db'], shell: 'bash', category: 'source' },
    // Monitoring Category
    { id: 'grafana', name: 'Grafana', port: 9904, container: 'devopslab-grafana', icon: '📊', description: 'Monitoring Dashboard', volumes: ['devopslab_grafana_data'], shell: 'sh', category: 'monitoring' },
    { id: 'prometheus', name: 'Prometheus', port: 9905, container: 'devopslab-prometheus', icon: '📈', description: 'Metrics Collection', volumes: ['devopslab_prometheus_data'], shell: 'sh', category: 'monitoring' },
    { id: 'cadvisor', name: 'cAdvisor', port: 9906, container: 'devopslab-cadvisor', icon: '📉', description: 'Container Metrics', volumes: [], shell: 'sh', category: 'monitoring' },
    // Infrastructure Category
    { id: 'portainer', name: 'Portainer', port: 9901, container: 'devopslab-portainer', icon: '🐳', description: 'Container Management', volumes: ['devopslab_portainer_data'], shell: null, category: 'infra' },
    { id: 'nexus', name: 'Nexus Repository', port: 9908, container: 'devopslab-nexus', icon: '🗃️', description: 'Artifact Repository', volumes: ['devopslab_nexus_data'], shell: 'bash', category: 'infra' },
    { id: 'dashboard', name: 'Dashboard', port: 9900, container: 'devopslab-dashboard', icon: '🚀', description: 'DevOpsLab Dashboard', volumes: [], shell: 'sh', category: 'infra' },
];

// Category definitions
const categories = {
    cicd: { name: 'CI/CD', icon: '🔨', order: 1 },
    source: { name: 'Source Control', icon: '📚', order: 2 },
    monitoring: { name: 'Monitoring', icon: '📊', order: 3 },
    infra: { name: 'Infrastructure', icon: '🏗️', order: 4 }
};

// Get categories
app.get('/api/categories', (req, res) => {
    res.json(categories);
});

// Get all services with their status
app.get('/api/services', async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const servicesWithStatus = await Promise.all(services.map(async (service) => {
            const container = containers.find(c => c.Names.some(n => n === `/${service.container}`));
            let status = 'stopped';
            let health = 'unknown';

            if (container) {
                status = container.State;
                health = container.Status;
            }

            return {
                ...service,
                categoryInfo: categories[service.category],
                hasShell: service.shell !== null,
                status,
                health,
                url: service.port ? `http://localhost:${service.port}` : null
            };
        }));

        res.json(servicesWithStatus);
    } catch (error) {
        console.error('Error fetching services:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get all containers
app.get('/api/containers', async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const devopsContainers = containers.filter(c =>
            c.Names.some(n => n.includes('devopslab'))
        ).map(c => ({
            id: c.Id.substring(0, 12),
            name: c.Names[0].replace('/', ''),
            status: c.State,
            health: c.Status,
            image: c.Image
        }));

        res.json(devopsContainers);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Start/Stop container
app.post('/api/containers/:name/:action', async (req, res) => {
    try {
        const { name, action } = req.params;
        const container = docker.getContainer(name);

        if (action === 'start') {
            await container.start();
        } else if (action === 'stop') {
            await container.stop();
        } else if (action === 'restart') {
            await container.restart();
        }

        res.json({ success: true, message: `Container ${action}ed successfully` });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Cleanup volume
app.post('/api/volumes/:name/cleanup', async (req, res) => {
    try {
        const { name } = req.params;
        const service = services.find(s => s.id === name);

        if (!service) {
            return res.status(404).json({ error: 'Service not found' });
        }

        // Stop the container first
        try {
            const container = docker.getContainer(service.container);
            await container.stop();
        } catch (e) {
            console.log('Container already stopped or not found');
        }

        // Remove volumes
        for (const volName of service.volumes) {
            try {
                const volume = docker.getVolume(volName);
                await volume.remove();
                console.log(`Removed volume: ${volName}`);
            } catch (e) {
                console.log(`Could not remove volume ${volName}:`, e.message);
            }
        }

        // Restart the container
        try {
            const container = docker.getContainer(service.container);
            await container.start();
        } catch (e) {
            console.log('Could not restart container:', e.message);
        }

        res.json({ success: true, message: `Volumes cleaned for ${service.name}` });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get volumes
app.get('/api/volumes', async (req, res) => {
    try {
        const volumes = await docker.listVolumes();
        const devopsVolumes = volumes.Volumes.filter(v =>
            v.Name.includes('devopslab')
        ).map(v => ({
            name: v.Name,
            driver: v.Driver,
            mountpoint: v.Mountpoint
        }));

        res.json(devopsVolumes);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get Jenkins agents
app.get('/api/jenkins-agents', async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const agents = containers.filter(c =>
            c.Names.some(n => n.includes('devopslab-jenkins-agent'))
        ).map(c => ({
            id: c.Id.substring(0, 12),
            name: c.Names[0].replace('/', ''),
            status: c.State,
            health: c.Status
        }));
        res.json(agents);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Scale Jenkins agents
app.post('/api/jenkins-agents/scale', async (req, res) => {
    const { count } = req.body;

    if (!count || count < 0 || count > 10) {
        return res.status(400).json({ error: 'Count must be between 0 and 10' });
    }

    try {
        const { exec } = require('child_process');
        const util = require('util');
        const execPromise = util.promisify(exec);

        // Get current agent count
        const containers = await docker.listContainers({ all: true });
        const currentAgents = containers.filter(c =>
            c.Names.some(n => n.includes('devopslab-jenkins-agent'))
        );

        const currentCount = currentAgents.length;

        if (count === currentCount) {
            return res.json({ success: true, message: `Already have ${count} agents` });
        }

        // Use docker compose to scale
        const composeDir = '/app/../..';
        const { stdout, stderr } = await execPromise(
            `cd ${composeDir} && docker compose up -d --scale jenkins-agent-1=${count > 0 ? 1 : 0} --scale jenkins-agent-2=${count > 1 ? 1 : 0} --no-recreate 2>&1 || true`
        );

        console.log('Scale output:', stdout);
        if (stderr) console.error('Scale stderr:', stderr);

        res.json({
            success: true,
            message: `Scaled Jenkins agents from ${currentCount} to ${count}`,
            previousCount: currentCount,
            newCount: count
        });
    } catch (error) {
        console.error('Scale error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Start/Stop a specific Jenkins agent
app.post('/api/jenkins-agents/:action/:agentName', async (req, res) => {
    const { action, agentName } = req.params;

    if (!['start', 'stop'].includes(action)) {
        return res.status(400).json({ error: 'Action must be start or stop' });
    }

    try {
        const container = docker.getContainer(agentName);

        if (action === 'start') {
            await container.start();
        } else {
            await container.stop();
        }

        res.json({ success: true, message: `${action}ed agent ${agentName}` });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// WebSocket for terminal
wss.on('connection', (ws, req) => {
    const urlParams = new URLSearchParams(req.url.split('?')[1]);
    const containerName = urlParams.get('container');

    if (!containerName) {
        ws.close();
        return;
    }

    console.log(`Terminal connection for: ${containerName}`);

    // Find service config to get shell type
    const service = services.find(s => s.container === containerName);
    const shellType = service?.shell || 'sh'; // Default to sh
    const shellCmd = shellType === 'bash' ? '/bin/bash' : '/bin/sh';

    if (service && service.shell === null) {
        ws.send(`Error: This container does not have a shell\r\n`);
        ws.close();
        return;
    }

    const container = docker.getContainer(containerName);

    console.log(`Using shell: ${shellCmd}`);

    // Helper function to setup stream
    const setupStream = (stream) => {
        stream.on('data', (chunk) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(chunk.toString('utf8'));
            }
        });

        ws.on('message', (message) => {
            stream.write(message);
        });

        ws.on('close', () => {
            stream.end();
        });

        stream.on('end', () => {
            ws.close();
        });
    };

    // Try preferred shell first
    container.exec({
        Cmd: [shellCmd],
        AttachStdin: true,
        AttachStdout: true,
        AttachStderr: true,
        Tty: true
    }).then(exec => {
        return exec.start({
            hijack: true,
            stdin: true
        });
    }).then(stream => {
        setupStream(stream);
    }).catch(err => {
        console.error('Exec error with preferred shell:', err.message);
        // Try fallback shell
        const fallbackCmd = shellCmd === '/bin/bash' ? '/bin/sh' : '/bin/bash';
        container.exec({
            Cmd: [fallbackCmd],
            AttachStdin: true,
            AttachStdout: true,
            AttachStderr: true,
            Tty: true
        }).then(exec => {
            return exec.start({
                hijack: true,
                stdin: true
            });
        }).then(stream => {
            setupStream(stream);
        }).catch(err2 => {
            console.error('Fallback exec error:', err2.message);
            ws.send(`Error: Could not start shell - ${err2.message}\r\n`);
            ws.close();
        });
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`DevOpsLab Dashboard running on port ${PORT}`);
});
