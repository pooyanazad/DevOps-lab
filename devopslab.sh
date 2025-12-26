#!/bin/bash

# DevOpsLab Management Script
# This script helps manage the DevOpsLab environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
fi

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                    DevOpsLab Manager                       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_help() {
    print_banner
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start         - Start all services"
    echo "  stop          - Stop all services"
    echo "  restart       - Restart all services"
    echo "  status        - Show status of all services"
    echo "  logs          - Show logs of all services"
    echo "  logs <svc>    - Show logs of specific service"
    echo "  build         - Build/rebuild all images"
    echo "  pull          - Pull latest images"
    echo "  cleanup       - Remove all volumes (WARNING: data loss)"
    echo "  cleanup-jenkins - Clean Jenkins volumes only"
    echo "  cleanup-gitea   - Clean Gitea volumes only"
    echo "  info          - Show service URLs and credentials"
    echo "  shell <svc>   - Open shell in a service container"
    echo "  help          - Show this help message"
    echo ""
}

print_info() {
    print_banner
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    Service URLs                            ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Dashboard (Heimdall)${NC}:  http://localhost:${DASHBOARD_PORT:-9900}"
    echo -e "  ${YELLOW}Portainer${NC}:             http://localhost:${PORTAINER_PORT:-9901}"
    echo -e "  ${YELLOW}Jenkins${NC}:               http://localhost:${JENKINS_PORT:-9902}"
    echo -e "  ${YELLOW}Gitea${NC}:                 http://localhost:${GITEA_PORT:-9903}"
    echo -e "  ${YELLOW}Grafana${NC}:               http://localhost:${GRAFANA_PORT:-9904}"
    echo -e "  ${YELLOW}Prometheus${NC}:            http://localhost:${PROMETHEUS_PORT:-9905}"
    echo -e "  ${YELLOW}cAdvisor${NC}:              http://localhost:${CADVISOR_PORT:-9906}"
    echo -e "  ${YELLOW}Node Exporter${NC}:         http://localhost:${NODE_EXPORTER_PORT:-9907}"
    echo -e "  ${YELLOW}Docker Registry${NC}:       http://localhost:${REGISTRY_PORT:-9908}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    Credentials                             ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}Jenkins${NC}:"
    echo -e "    Username: ${JENKINS_ADMIN_USER:-admin}"
    echo -e "    Password: ${JENKINS_ADMIN_PASSWORD:-admin123}"
    echo ""
    echo -e "  ${YELLOW}Gitea${NC}:"
    echo -e "    Username: ${GITEA_ADMIN_USER:-gitadmin}"
    echo -e "    Password: ${GITEA_ADMIN_PASSWORD:-gitadmin123}"
    echo ""
    echo -e "  ${YELLOW}Grafana${NC}:"
    echo -e "    Username: ${GRAFANA_ADMIN_USER:-admin}"
    echo -e "    Password: ${GRAFANA_ADMIN_PASSWORD:-admin123}"
    echo ""
    echo -e "  ${YELLOW}Portainer${NC}:"
    echo -e "    Username: admin"
    echo -e "    Password: ${PORTAINER_ADMIN_PASSWORD:-admin123456789}"
    echo ""
}

start_services() {
    echo -e "${GREEN}Starting DevOpsLab services...${NC}"
    docker compose -f "$COMPOSE_FILE" up -d
    echo -e "${GREEN}Services started!${NC}"
    print_info
}

stop_services() {
    echo -e "${YELLOW}Stopping DevOpsLab services...${NC}"
    docker compose -f "$COMPOSE_FILE" down
    echo -e "${GREEN}Services stopped!${NC}"
}

restart_services() {
    stop_services
    start_services
}

show_status() {
    echo -e "${BLUE}DevOpsLab Services Status:${NC}"
    docker compose -f "$COMPOSE_FILE" ps
}

show_logs() {
    if [ -z "$1" ]; then
        docker compose -f "$COMPOSE_FILE" logs -f
    else
        docker compose -f "$COMPOSE_FILE" logs -f "$1"
    fi
}

build_images() {
    echo -e "${YELLOW}Building DevOpsLab images...${NC}"
    docker compose -f "$COMPOSE_FILE" build
    echo -e "${GREEN}Build complete!${NC}"
}

pull_images() {
    echo -e "${YELLOW}Pulling latest images...${NC}"
    docker compose -f "$COMPOSE_FILE" pull
    echo -e "${GREEN}Pull complete!${NC}"
}

cleanup_all() {
    echo -e "${RED}WARNING: This will delete ALL data volumes!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}Stopping services and removing volumes...${NC}"
        docker compose -f "$COMPOSE_FILE" down -v
        echo -e "${GREEN}Cleanup complete!${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled.${NC}"
    fi
}

cleanup_jenkins() {
    echo -e "${RED}WARNING: This will delete Jenkins data!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}Removing Jenkins volumes...${NC}"
        docker compose -f "$COMPOSE_FILE" stop jenkins jenkins-agent-1 jenkins-agent-2
        docker volume rm devopslab_jenkins_home devopslab_jenkins_agent1_home devopslab_jenkins_agent2_home 2>/dev/null || true
        echo -e "${GREEN}Jenkins cleanup complete! Restart to recreate.${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled.${NC}"
    fi
}

cleanup_gitea() {
    echo -e "${RED}WARNING: This will delete Gitea data!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}Removing Gitea volumes...${NC}"
        docker compose -f "$COMPOSE_FILE" stop gitea gitea-db
        docker volume rm devopslab_gitea_data devopslab_gitea_db 2>/dev/null || true
        echo -e "${GREEN}Gitea cleanup complete! Restart to recreate.${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled.${NC}"
    fi
}

open_shell() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify a service name${NC}"
        echo "Available services:"
        docker compose -f "$COMPOSE_FILE" ps --services
        exit 1
    fi
    docker compose -f "$COMPOSE_FILE" exec "$1" /bin/bash || docker compose -f "$COMPOSE_FILE" exec "$1" /bin/sh
}

# Main command handler
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    build)
        build_images
        ;;
    pull)
        pull_images
        ;;
    cleanup)
        cleanup_all
        ;;
    cleanup-jenkins)
        cleanup_jenkins
        ;;
    cleanup-gitea)
        cleanup_gitea
        ;;
    info)
        print_info
        ;;
    shell)
        open_shell "$2"
        ;;
    help|--help|-h)
        print_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        print_help
        exit 1
        ;;
esac
