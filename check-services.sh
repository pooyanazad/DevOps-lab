#!/bin/bash
set -e

echo "DevOps Lab Services Status Check"
echo "================================="

# Check network
echo "Checking network..."
docker network inspect devops_network >/dev/null 2>&1 || { echo "Network not found!"; exit 1; }
echo "Network is up ✅"

# Function to check services
check_service() {
  SERVICE=$1
  IP=$2
  PORT=$3
  echo -n "Checking $SERVICE ($IP:$PORT)... "
  if docker ps | grep -q $SERVICE; then
    if [[ -n "$PORT" ]]; then
      if nc -z $IP $PORT >/dev/null 2>&1; then
        echo "UP ✅"
        return 0
      else
        echo "PORT NOT RESPONDING ❌"
        return 1
      fi
    else
      echo "UP ✅"
      return 0
    fi
  else
    echo "DOWN ❌"
    return 1
  fi
}

# Check all services
check_service "usm" "172.20.0.2" "80"
check_service "gitlab" "172.20.0.3" "80"
check_service "nexus" "172.20.0.4" "8081"
check_service "sonarqube" "172.20.0.5" "9000"
check_service "sonarqube-db" "172.20.0.6" "5432"
check_service "devops-tools" "172.20.0.7" ""
check_service "minikube" "172.20.0.8" "8080"
check_service "selenium-hub" "172.20.0.9" "4444"
check_service "selenium-chrome" "172.20.0.10" ""
check_service "selenium-firefox" "172.20.0.11" ""
check_service "elasticsearch" "172.20.0.12" "9200"
check_service "logstash" "172.20.0.13" "5000"
check_service "kibana" "172.20.0.14" "5601"

echo "================================="
echo "Detailed container information:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"