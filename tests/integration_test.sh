#!/bin/bash
# =============================================================================
# DevOpsLab Integration Tests (QA Tests)
# Tests that components work together correctly
# These tests validate configuration consistency and component integration
# =============================================================================

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_start() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  INTEGRATION TESTS - Component Validation${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
    ((TOTAL++))
}

test_fail() {
    echo -e "  ${RED}✗ FAIL${NC}: $1"
    echo -e "    ${YELLOW}Reason${NC}: $2"
    ((FAILED++))
    ((TOTAL++))
}

test_summary() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Total:  ${TOTAL}"
    echo -e "  ${GREEN}Passed${NC}: ${PASSED}"
    echo -e "  ${RED}Failed${NC}: ${FAILED}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    generate_junit_report "integration"
    
    if [ $FAILED -gt 0 ]; then
        return 1
    fi
    return 0
}

generate_junit_report() {
    local test_type=$1
    local report_file="${SCRIPT_DIR}/reports/${test_type}-results.xml"
    mkdir -p "${SCRIPT_DIR}/reports"
    
    cat > "$report_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="DevOpsLab ${test_type^} Tests" tests="${TOTAL}" failures="${FAILED}" time="0">
  <testsuite name="${test_type}" tests="${TOTAL}" failures="${FAILED}">
    <testcase name="integration_validation" classname="devopslab.${test_type}">
      $(if [ $FAILED -gt 0 ]; then echo "<failure message=\"${FAILED} tests failed\"/>"; fi)
    </testcase>
  </testsuite>
</testsuites>
EOF
    echo -e "\n  📄 Report saved: ${report_file}"
}

# =============================================================================
# ENV AND COMPOSE INTEGRATION
# =============================================================================

test_env_compose_port_consistency() {
    if [ -f "${PROJECT_DIR}/.env" ] && [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        source "${PROJECT_DIR}/.env"
        local compose=$(cat "${PROJECT_DIR}/docker-compose.yml")
        
        # Check that env vars used in compose exist
        local env_vars=$(echo "$compose" | grep -oE '\$\{[A-Z_]+\}' | sort -u | sed 's/[${}]//g')
        local missing=0
        
        for var in $env_vars; do
            if [ -z "${!var}" ]; then
                missing=$((missing + 1))
            fi
        done
        
        if [ $missing -eq 0 ]; then
            test_pass "All docker-compose environment variables are defined in .env"
        else
            test_fail "Env/Compose consistency" "${missing} variables used in compose but not in .env"
        fi
    else
        test_fail "Env/Compose consistency" "Missing .env or docker-compose.yml"
    fi
}

test_port_no_conflicts() {
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env"
        
        local ports=(
            "${DASHBOARD_PORT:-9900}"
            "${PORTAINER_PORT:-9901}"
            "${JENKINS_PORT:-9902}"
            "${GITEA_PORT:-9903}"
            "${GRAFANA_PORT:-9904}"
            "${PROMETHEUS_PORT:-9905}"
            "${CADVISOR_PORT:-9906}"
            "${NODE_EXPORTER_PORT:-9907}"
            "${REGISTRY_PORT:-9908}"
        )
        
        local sorted=$(printf '%s\n' "${ports[@]}" | sort)
        local unique=$(printf '%s\n' "${ports[@]}" | sort -u)
        
        if [ "$sorted" = "$unique" ]; then
            test_pass "No port conflicts in configuration"
        else
            test_fail "Port conflicts" "Duplicate ports found in configuration"
        fi
    else
        test_fail "Port conflicts" ".env not found"
    fi
}

# =============================================================================
# DASHBOARD AND SERVER INTEGRATION
# =============================================================================

test_dashboard_api_endpoints_defined() {
    if [ -f "${PROJECT_DIR}/dashboard/server.js" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/server.js")
        
        local endpoints=("/api/services" "/api/containers" "/api/volumes")
        local missing=0
        
        for endpoint in "${endpoints[@]}"; do
            if ! echo "$content" | grep -q "'${endpoint}'"; then
                missing=$((missing + 1))
            fi
        done
        
        if [ $missing -eq 0 ]; then
            test_pass "All required API endpoints are defined in server.js"
        else
            test_fail "API endpoints" "${missing} endpoints missing"
        fi
    else
        test_fail "API endpoints" "server.js not found"
    fi
}

test_dashboard_frontend_api_calls() {
    if [ -f "${PROJECT_DIR}/dashboard/public/app.js" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/public/app.js")
        
        # Check frontend calls the APIs defined in backend
        local has_services=$(echo "$content" | grep -c "/api/services" || true)
        local has_containers=$(echo "$content" | grep -c "/api/containers" || true)
        
        if [ "$has_services" -gt 0 ] && [ "$has_containers" -gt 0 ]; then
            test_pass "Frontend correctly calls backend API endpoints"
        else
            test_fail "Frontend API calls" "Missing API calls in app.js"
        fi
    else
        test_fail "Frontend API calls" "app.js not found"
    fi
}

test_dashboard_html_loads_assets() {
    if [ -f "${PROJECT_DIR}/dashboard/public/index.html" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/public/index.html")
        
        local has_css=$(echo "$content" | grep -c "styles.css" || true)
        local has_js=$(echo "$content" | grep -c "app.js" || true)
        
        if [ "$has_css" -gt 0 ] && [ "$has_js" -gt 0 ]; then
            test_pass "index.html correctly references CSS and JS files"
        else
            test_fail "HTML asset references" "Missing styles.css or app.js reference"
        fi
    else
        test_fail "HTML asset references" "index.html not found"
    fi
}

# =============================================================================
# JENKINS CONFIGURATION INTEGRATION
# =============================================================================

test_jenkins_plugins_valid() {
    if [ -f "${PROJECT_DIR}/context/jenkins/plugins.txt" ]; then
        local content=$(cat "${PROJECT_DIR}/context/jenkins/plugins.txt")
        local line_count=$(echo "$content" | grep -v '^$' | wc -l)
        
        # Check plugins are not empty and have reasonable count
        if [ "$line_count" -gt 5 ]; then
            test_pass "Jenkins plugins.txt has ${line_count} plugins defined"
        else
            test_fail "Jenkins plugins" "Too few plugins defined (${line_count})"
        fi
    else
        test_fail "Jenkins plugins" "plugins.txt not found"
    fi
}

test_jenkins_init_scripts_exist() {
    local scripts=(
        "context/jenkins/init.groovy.d/01-disable-setup-wizard.groovy"
        "context/jenkins/init.groovy.d/02-create-admin.groovy"
        "context/jenkins/init.groovy.d/03-configure-agents.groovy"
        "context/jenkins/init.groovy.d/04-create-test-pipeline.groovy"
    )
    
    local missing=0
    for script in "${scripts[@]}"; do
        if [ ! -f "${PROJECT_DIR}/${script}" ]; then
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        test_pass "All Jenkins init scripts exist (${#scripts[@]} scripts)"
    else
        test_fail "Jenkins init scripts" "${missing} scripts missing"
    fi
}

test_jenkins_agent_env_vars() {
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/docker-compose.yml")
        
        # Check jenkins-agent has required env vars
        local has_url=$(echo "$content" | grep -A20 "jenkins-agent-1:" | grep -c "JENKINS_URL" || true)
        local has_name=$(echo "$content" | grep -A20 "jenkins-agent-1:" | grep -c "JENKINS_AGENT_NAME" || true)
        
        if [ "$has_url" -gt 0 ] && [ "$has_name" -gt 0 ]; then
            test_pass "Jenkins agent has required environment variables"
        else
            test_fail "Jenkins agent config" "Missing JENKINS_URL or JENKINS_AGENT_NAME"
        fi
    else
        test_fail "Jenkins agent config" "docker-compose.yml not found"
    fi
}

# =============================================================================
# MONITORING STACK INTEGRATION
# =============================================================================

test_prometheus_scrape_targets() {
    if [ -f "${PROJECT_DIR}/config/prometheus/prometheus.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/config/prometheus/prometheus.yml")
        
        # Check for scrape configs
        local has_cadvisor=$(echo "$content" | grep -c "cadvisor" || true)
        local has_jenkins=$(echo "$content" | grep -c "jenkins" || true)
        
        if [ "$has_cadvisor" -gt 0 ] && [ "$has_jenkins" -gt 0 ]; then
            test_pass "Prometheus has cadvisor and jenkins targets"
        else
            test_fail "Prometheus targets" "Missing cadvisor or jenkins"
        fi
    else
        test_fail "Prometheus targets" "prometheus.yml not found"
    fi
}

test_grafana_datasource_prometheus() {
    if [ -f "${PROJECT_DIR}/config/grafana/provisioning/datasources/datasources.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/config/grafana/provisioning/datasources/datasources.yml")
        
        local has_prometheus=$(echo "$content" | grep -c "prometheus" || true)
        local has_url=$(echo "$content" | grep -c "url:" || true)
        
        if [ "$has_prometheus" -gt 0 ] && [ "$has_url" -gt 0 ]; then
            test_pass "Grafana has Prometheus datasource configured"
        else
            test_fail "Grafana datasource" "Prometheus datasource not configured"
        fi
    else
        test_fail "Grafana datasource" "datasources.yml not found"
    fi
}

test_grafana_dashboards_provisioning() {
    if [ -f "${PROJECT_DIR}/config/grafana/provisioning/dashboards/dashboards.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/config/grafana/provisioning/dashboards/dashboards.yml")
        
        local has_provider=$(echo "$content" | grep -c "providers:" || true)
        local has_path=$(echo "$content" | grep -c "path:" || true)
        
        if [ "$has_provider" -gt 0 ]; then
            test_pass "Grafana dashboard provisioning is configured"
        else
            test_fail "Grafana dashboards" "Dashboard provisioning not configured"
        fi
    else
        test_fail "Grafana dashboards" "dashboards.yml not found"
    fi
}

# =============================================================================
# DOCKER NETWORK INTEGRATION
# =============================================================================

test_all_services_same_network() {
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/docker-compose.yml")
        
        # Count services using devopslab network
        local network_refs=$(grep -c "devopslab" "${PROJECT_DIR}/docker-compose.yml" || echo "0")
        
        if [ "$network_refs" -gt 5 ]; then
            test_pass "All services use the same Docker network (${network_refs} refs)"
        else
            test_fail "Docker network" "Not all services use devopslab network (found ${network_refs})"
        fi
    else
        test_fail "Docker network" "docker-compose.yml not found"
    fi
}

# =============================================================================
# VOLUME CONFIGURATION
# =============================================================================

test_volumes_defined() {
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/docker-compose.yml")
        
        local volumes=(
            "jenkins_home"
            "grafana_data"
            "prometheus_data"
            "portainer_data"
        )
        
        local missing=0
        for vol in "${volumes[@]}"; do
            if ! echo "$content" | grep -q "${vol}:"; then
                missing=$((missing + 1))
            fi
        done
        
        if [ $missing -eq 0 ]; then
            test_pass "All required volumes are defined"
        else
            test_fail "Volume definitions" "${missing} volumes missing"
        fi
    else
        test_fail "Volume definitions" "docker-compose.yml not found"
    fi
}

# =============================================================================
# RUN TESTS
# =============================================================================

test_start

echo -e "\n${YELLOW}⚙️ Configuration Integration${NC}"
test_env_compose_port_consistency
test_port_no_conflicts

echo -e "\n${YELLOW}🖥️ Dashboard Integration${NC}"
test_dashboard_api_endpoints_defined
test_dashboard_frontend_api_calls
test_dashboard_html_loads_assets

echo -e "\n${YELLOW}🔧 Jenkins Integration${NC}"
test_jenkins_plugins_valid
test_jenkins_init_scripts_exist
test_jenkins_agent_env_vars

echo -e "\n${YELLOW}📊 Monitoring Stack Integration${NC}"
test_prometheus_scrape_targets
test_grafana_datasource_prometheus
test_grafana_dashboards_provisioning

echo -e "\n${YELLOW}🐳 Docker Integration${NC}"
test_all_services_same_network
test_volumes_defined

test_summary
