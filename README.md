# DevOps Lab Docker Environment

A comprehensive containerized DevOps environment with integrated tools for development, CI/CD, testing, monitoring, and infrastructure management.

## Overview

This repository contains a complete DevOps lab environment deployed through Docker Compose. All services are connected on the same network with fixed IPs and centralized access through a Universal Service Manager (USM).

## Components

| Service | Description | IP Address | Default Port |
|---------|-------------|------------|--------------|
| **USM** | Universal Service Manager with Nginx | 172.20.0.2 | 80, 443 |
| **GitLab** | Source code management and CI/CD | 172.20.0.3 | 8080, 8022, 5050 |
| **Nexus** | Artifact repository manager | 172.20.0.4 | 8081, 8082 |
| **SonarQube** | Code quality and security analysis | 172.20.0.5 | 9000 |
| **SonarQube DB** | PostgreSQL database for SonarQube | 172.20.0.6 | 5432 |
| **DevOps Tools** | Terraform and Ansible toolkit | 172.20.0.7 | N/A |
| **Minikube** | Local Kubernetes environment | 172.20.0.8 | 30000 |
| **Selenium Hub** | Test automation framework | 172.20.0.9 | 4444 |
| **Selenium Chrome** | Chrome browser for automated testing | 172.20.0.10 | N/A |
| **Selenium Firefox** | Firefox browser for automated testing | 172.20.0.11 | N/A |
| **Elasticsearch** | Log and data storage/search | 172.20.0.12 | 9200, 9300 |
| **Logstash** | Log collection and processing | 172.20.0.13 | 5000, 9600 |
| **Kibana** | Data visualization and ELK management | 172.20.0.14 | 5601 |

## System Requirements

- **CPU**: 4+ cores recommended (2 cores minimum)
- **RAM**: 16GB+ recommended (8GB minimum)
- **Disk Space**: 20GB+ free space
- **Operating System**: Linux, macOS, or Windows with Docker Desktop
- **Docker**: Docker Engine 20.10.0+ and Docker Compose 2.0.0+
- **Network**: Outbound internet access for pulling images

## Getting Started

### Prerequisites

1. Install Docker and Docker Compose
2. Ensure ports 80, 443, and other service ports are available
3. Clone this repository

### Installation

1. Create the necessary directory structure:

```bash
mkdir -p devops-lab/{usm/{nginx,html,ssl},devops-tools/{projects,ssh},elk/logstash/pipeline}
```

2. Copy all configuration files to their respective locations:

```bash
# Copy docker-compose.yml to the root directory
cp docker-compose.yml devops-lab/

# Copy Dockerfiles
cp usm/Dockerfile devops-lab/usm/
cp devops-tools/Dockerfile devops-lab/devops-tools/

# Copy configuration files
cp usm/nginx/default.conf devops-lab/usm/nginx/
cp usm/html/index.html devops-lab/usm/html/
cp elk/logstash/pipeline/logstash.conf devops-lab/elk/logstash/pipeline/

# Copy service check script
cp check-services.sh devops-lab/
chmod +x devops-lab/check-services.sh
```

3. Start the environment:

```bash
cd devops-lab
docker-compose up -d
```

4. Monitor the startup process:

```bash
docker-compose logs -f
```

5. Check service status:

```bash
./check-services.sh
```

## Accessing Services

### Universal Service Manager (USM)

The USM serves as the central entry point to all services.

- **URL**: http://localhost
- **Description**: Central dashboard for accessing all services

### GitLab

- **URL**: http://localhost:8080
- **Direct URL**: http://172.20.0.3
- **Container Registry**: http://localhost:5050
- **SSH**: localhost:8022
- **Default Credentials**: 
  - Username: root
  - Password: devops_password

### Nexus Repository

- **URL**: http://localhost:8081
- **Direct URL**: http://172.20.0.4
- **Docker Repository Port**: 8082
- **Default Credentials**:
  - Username: admin
  - Password: Find in logs with `docker logs nexus | grep "admin user"`

### SonarQube

- **URL**: http://localhost:9000
- **Direct URL**: http://172.20.0.5
- **Default Credentials**:
  - Username: admin
  - Password: admin

### ELK Stack

- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601
- **Logstash TCP Input**: 5000

### Selenium Grid

- **Hub URL**: http://localhost:4444
- **Browsers**: Chrome, Firefox

### Kubernetes (Minikube)

- **Sample App URL**: http://localhost:30000

## Using the DevOps Tools Container

The DevOps Tools container comes with Terraform and Ansible pre-installed.

```bash
# Connect to the container
docker exec -it devops-tools bash

# Verify installations
terraform --version
ansible --version

# Use the tools
cd /projects
# Create your Terraform and Ansible files here
```

## Working with GitLab Container Registry

1. Login to the registry:

```bash
docker login localhost:5050 -u root -p devops_password
```

2. Tag and push an image:

```bash
docker tag your-image:tag localhost:5050/project-name/your-image:tag
docker push localhost:5050/project-name/your-image:tag
```

## Testing the ELK Stack

1. Send test logs to Logstash:

```bash
echo '{"message":"Test log message", "type":"docker", "service":"test-service"}' | nc 172.20.0.13 5000
```

2. View logs in Kibana (http://localhost:5601)

## Maintenance

### Checking Logs

```bash
docker-compose logs [service_name]
```

### Restarting Services

```bash
docker-compose restart [service_name]
```

### Stopping the Environment

```bash
docker-compose down
```

### Complete Reset

```bash
docker-compose down -v
docker-compose up -d
```

## Data Persistence

The following volumes are created to persist data:

- `gitlab_config`, `gitlab_logs`, `gitlab_data`
- `nexus_data`
- `sonarqube_data`, `sonarqube_logs`, `sonarqube_extensions`, `sonarqube_db`
- `elasticsearch_data`

## Network Configuration

All services are connected to a custom bridge network (`devops_network`) with the subnet `172.20.0.0/16`.

## Troubleshooting

### Common Issues

1. **Service fails to start**:
   - Check logs: `docker-compose logs [service_name]`
   - Verify resource availability: `docker stats`

2. **Connectivity issues**:
   - Test network: `docker exec -it usm ping [service_name]`
   - Check service status: `./check-services.sh`

3. **GitLab is slow to start**:
   - This is normal. GitLab may take several minutes to initialize.
   - Check the logs for progress: `docker-compose logs gitlab`

4. **Out of memory errors**:
   - Increase Docker's memory allocation in Docker Desktop settings
   - Consider running fewer services simultaneously

## Security Notes

- Default credentials are used for demonstration purposes
- For production use, change all default passwords
- Consider implementing SSL for secure communication

## Customization

### Adding Custom Configuration Files

1. Add files to the appropriate directory
2. Rebuild the container: `docker-compose up -d --build [service_name]`

### Modifying Service Parameters

1. Edit the `docker-compose.yml` file
2. Apply changes: `docker-compose up -d`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Docker and Docker Compose
- GitLab, Nexus, SonarQube, ELK Stack, Selenium, and other open-source tools
