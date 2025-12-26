# DevOpsLab 🚀

A complete DevOps laboratory environment running on Docker. Start your entire DevOps infrastructure with a single command!

## 🎯 Features

- **Single Command Deployment**: Start everything with `docker compose up -d`
- **Centralized Dashboard**: Web-based dashboard to access all services at port 9900
- **Web-based Container Management**: Use Portainer for container management and web terminal access
- **Pre-configured Jenkins**: With 2 Ubuntu-based Docker agents ready to go
- **Git Repository**: Gitea for hosting your code
- **Monitoring Stack**: Grafana + Prometheus + cAdvisor for complete visibility
- **Artifact Repository**: Nexus Repository Manager for storing artifacts
- **Easy Configuration**: All credentials in a single `.env` file

## 📋 Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| DevOpsLab Dashboard | 9900 | Main dashboard to access all services |
| Portainer | 9901 | Container management & web terminal |
| Jenkins | 9902 | CI/CD automation server |
| Gitea | 9903 | Git repository server |
| Grafana | 9904 | Monitoring dashboards |
| Prometheus | 9905 | Metrics collection |
| cAdvisor | 9906 | Container metrics |
| Nexus Repository | 9909 | Artifact repository manager |

## 🚀 Quick Start

### Prerequisites

- **Linux**: Docker & Docker Compose installed
- **Windows**: WSL2 & Docker Desktop installed

---

### 🐧 Running on Linux

```bash
# Clone the repository
git clone https://github.com/pooyanazad/DevOps-lab.git
cd DevOps-lab

# Make the management script executable
chmod +x devopslab.sh

# Start all services
./devopslab.sh start

# Or use docker compose directly
docker compose up -d
```

### 🪟 Running on Windows (WSL2 + Docker Desktop)

Open **Ubuntu/WSL terminal** and run:

```bash
# Clone the repository
git clone https://github.com/pooyanazad/DevOps-lab.git
cd DevOps-lab

# Make the management script executable
chmod +x devopslab.sh

# Start all services
./devopslab.sh start
```

> 💡 **Note**: Make sure Docker Desktop is running and WSL integration is enabled in Docker Desktop settings.

---

### Access the Dashboard

Open your browser and navigate to: **http://localhost:9900**

## 🔐 Default Credentials

All credentials are configured in the `.env` file:

| Service | Username | Password |
|---------|----------|----------|
| Jenkins | admin | admin123 |
| Gitea | gitadmin | gitadmin123 |
| Grafana | admin | admin123 |
| Portainer | admin | admin123456789 |

> ⚠️ **Important**: Change these credentials in production!

## 📦 Configuration

Edit the `.env` file to customize:

- Port mappings
- Usernames and passwords
- Timezone settings
- Database credentials

## 🛠️ Management Commands

Use the `devopslab.sh` script for common tasks:

```bash
./devopslab.sh start          # Start all services
./devopslab.sh stop           # Stop all services
./devopslab.sh restart        # Restart all services
./devopslab.sh status         # Show service status
./devopslab.sh logs           # View all logs
./devopslab.sh logs jenkins   # View Jenkins logs
./devopslab.sh build          # Rebuild images
./devopslab.sh cleanup        # Remove all data (⚠️ destructive)
./devopslab.sh cleanup-jenkins # Clean Jenkins data only
./devopslab.sh cleanup-gitea   # Clean Gitea data only
./devopslab.sh shell jenkins  # Open shell in Jenkins container
./devopslab.sh info           # Show URLs and credentials
```

## 🌐 Accessing Services

### DevOpsLab Dashboard
Access: http://localhost:9900

The custom dashboard provides:
- Overview of all running services
- Quick access links to each service
- Container status at a glance
- Web terminal access to containers
- Volume management

### Portainer - Container Management
Access: http://localhost:9901

### Jenkins
Access: http://localhost:9902

- 2 Ubuntu agents pre-configured and ready to connect
- Docker CLI available in all agents
- Blue Ocean UI installed for visual pipelines
- Test pipeline included: `test-pipeline-agent1`

### Gitea
Access: http://localhost:9903

- First time: Complete the setup wizard
- SSH access on port 2222

### Grafana
Access: http://localhost:9904

- Pre-configured Prometheus datasource
- Docker Containers dashboard included

### Nexus Repository Manager
Access: http://localhost:9909

- Store Maven, npm, Docker, and other artifacts

## 🤖 Jenkins Agents

Two Ubuntu-based Docker agents are pre-configured:

- `ubuntu-agent-1`: First Docker agent
- `ubuntu-agent-2`: Second Docker agent

Both agents have:
- Docker CLI installed
- Python 3
- Git
- Common build tools

## 🧹 Cleanup & Reset

### Clean Specific Service

```bash
# Clean Jenkins and rebuild from scratch
./devopslab.sh cleanup-jenkins
./devopslab.sh restart

# Clean Gitea and rebuild from scratch
./devopslab.sh cleanup-gitea
./devopslab.sh restart
```

### Full Reset

```bash
# Remove everything and start fresh
./devopslab.sh cleanup
./devopslab.sh start
```

## 🔧 Troubleshooting

### Jenkins agents not connecting

1. Wait 2-3 minutes for Jenkins to fully initialize
2. Check agent logs: `./devopslab.sh logs jenkins-agent-1`
3. Verify Jenkins is accessible: http://localhost:9902

### Port conflicts

Edit `.env` and change the conflicting port:
```bash
JENKINS_PORT=9920  # Change from 9902 to 9920
```

## 📁 Project Structure

```
DevOps-lab/
├── docker-compose.yml      # Main compose file
├── .env                    # Configuration file
├── devopslab.sh           # Management script
├── README.md              # This file
├── dashboard/             # Custom DevOpsLab Dashboard
│   ├── Dockerfile
│   ├── server.js
│   └── public/
├── config/
│   ├── grafana/
│   ├── prometheus/
│   └── portainer/
├── context/
│   ├── jenkins/
│   └── jenkins-agent/
└── tests/
```

## 🎓 Learning Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Gitea Documentation](https://docs.gitea.io/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

## 📝 License

This project is provided as-is for educational and development purposes.

---

**Happy DevOps Learning! 🎉**
