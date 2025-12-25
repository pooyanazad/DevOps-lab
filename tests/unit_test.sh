#!/bin/bash
# =============================================================================
# DevOpsLab Unit Tests
# Tests code syntax, configuration validity, and file structure
# These tests do NOT require running containers - they validate source code
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
    echo -e "${BLUE}  UNIT TESTS - Code Validation${NC}"
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
    
    generate_junit_report "unit"
    
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
EOF

    # Add individual test cases to XML (simplified)
    echo "    <testcase name=\"code_validation\" classname=\"devopslab.${test_type}\">" >> "$report_file"
    if [ $FAILED -gt 0 ]; then
        echo "      <failure message=\"${FAILED} tests failed\"/>" >> "$report_file"
    fi
    echo "    </testcase>" >> "$report_file"
    echo "  </testsuite>" >> "$report_file"
    echo "</testsuites>" >> "$report_file"
    
    echo -e "\n  📄 Report saved: ${report_file}"
}

# =============================================================================
# FILE STRUCTURE TESTS
# =============================================================================

test_required_files_exist() {
    local files=(
        "docker-compose.yml"
        ".env"
        "README.md"
        "devopslab.sh"
        "dashboard/server.js"
        "dashboard/package.json"
        "dashboard/Dockerfile"
        "dashboard/public/index.html"
        "dashboard/public/styles.css"
        "dashboard/public/app.js"
        "context/jenkins/Dockerfile"
        "context/jenkins/plugins.txt"
        "context/jenkins-agent/Dockerfile"
        "context/jenkins-agent/entrypoint.sh"
        "config/prometheus/prometheus.yml"
        "config/grafana/provisioning/datasources/datasources.yml"
        "config/grafana/provisioning/dashboards/dashboards.yml"
    )
    
    local missing=0
    local missing_files=""
    for file in "${files[@]}"; do
        if [ ! -f "${PROJECT_DIR}/${file}" ]; then
            missing=$((missing + 1))
            missing_files="${missing_files}\n      - ${file}"
        fi
    done
    
    if [ $missing -eq 0 ]; then
        test_pass "All required project files exist (${#files[@]} files)"
    else
        test_fail "Required files exist" "${missing} files missing:${missing_files}"
    fi
}

# =============================================================================
# YAML SYNTAX TESTS
# =============================================================================

test_yaml_syntax() {
    local yaml_files=(
        "docker-compose.yml"
        "config/prometheus/prometheus.yml"
        "config/grafana/provisioning/datasources/datasources.yml"
        "config/grafana/provisioning/dashboards/dashboards.yml"
    )
    
    local failed=0
    local failed_files=""
    
    for file in "${yaml_files[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            # Use Python to validate YAML syntax
            if command -v python3 &> /dev/null; then
                if ! python3 -c "import yaml; yaml.safe_load(open('${PROJECT_DIR}/${file}'))" 2>/dev/null; then
                    failed=$((failed + 1))
                    failed_files="${failed_files}\n      - ${file}"
                fi
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        test_pass "All YAML files have valid syntax"
    else
        test_fail "YAML syntax validation" "Invalid YAML:${failed_files}"
    fi
}

# =============================================================================
# JSON SYNTAX TESTS
# =============================================================================

test_json_syntax() {
    local json_files=(
        "dashboard/package.json"
        "config/grafana/dashboards/docker-containers.json"
    )
    
    local failed=0
    local failed_files=""
    
    for file in "${json_files[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            if command -v python3 &> /dev/null; then
                if ! python3 -c "import json; json.load(open('${PROJECT_DIR}/${file}'))" 2>/dev/null; then
                    failed=$((failed + 1))
                    failed_files="${failed_files}\n      - ${file}"
                fi
            elif command -v jq &> /dev/null; then
                if ! jq empty "${PROJECT_DIR}/${file}" 2>/dev/null; then
                    failed=$((failed + 1))
                    failed_files="${failed_files}\n      - ${file}"
                fi
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        test_pass "All JSON files have valid syntax"
    else
        test_fail "JSON syntax validation" "Invalid JSON:${failed_files}"
    fi
}

# =============================================================================
# JAVASCRIPT SYNTAX TESTS
# =============================================================================

test_javascript_syntax() {
    local js_files=(
        "dashboard/server.js"
        "dashboard/public/app.js"
    )
    
    local failed=0
    local failed_files=""
    
    for file in "${js_files[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            # Use Node.js to check syntax
            if command -v node &> /dev/null; then
                if ! node --check "${PROJECT_DIR}/${file}" 2>/dev/null; then
                    failed=$((failed + 1))
                    failed_files="${failed_files}\n      - ${file}"
                fi
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        test_pass "All JavaScript files have valid syntax"
    else
        test_fail "JavaScript syntax validation" "Invalid JS:${failed_files}"
    fi
}

# =============================================================================
# SHELL SCRIPT TESTS
# =============================================================================

test_shell_syntax() {
    local sh_files=(
        "devopslab.sh"
        "context/jenkins-agent/entrypoint.sh"
    )
    
    local failed=0
    local failed_files=""
    
    for file in "${sh_files[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            if ! bash -n "${PROJECT_DIR}/${file}" 2>/dev/null; then
                failed=$((failed + 1))
                failed_files="${failed_files}\n      - ${file}"
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        test_pass "All shell scripts have valid syntax"
    else
        test_fail "Shell script syntax validation" "Invalid scripts:${failed_files}"
    fi
}

# =============================================================================
# DOCKERFILE TESTS
# =============================================================================

test_dockerfile_syntax() {
    local dockerfiles=(
        "dashboard/Dockerfile"
        "context/jenkins/Dockerfile"
        "context/jenkins-agent/Dockerfile"
    )
    
    local failed=0
    local failed_files=""
    
    for file in "${dockerfiles[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            # Check for common Dockerfile issues
            local content=$(cat "${PROJECT_DIR}/${file}")
            
            # Must have FROM instruction
            if ! echo "$content" | grep -q "^FROM"; then
                failed=$((failed + 1))
                failed_files="${failed_files}\n      - ${file} (missing FROM)"
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        test_pass "All Dockerfiles have valid structure"
    else
        test_fail "Dockerfile validation" "Invalid Dockerfiles:${failed_files}"
    fi
}

# =============================================================================
# ENVIRONMENT CONFIGURATION TESTS
# =============================================================================

test_env_template() {
    if [ -f "${PROJECT_DIR}/.env" ]; then
        local required_vars=(
            "DASHBOARD_PORT"
            "PORTAINER_PORT"
            "JENKINS_PORT"
            "GRAFANA_PORT"
            "PROMETHEUS_PORT"
            "JENKINS_ADMIN_USER"
            "JENKINS_ADMIN_PASSWORD"
            "GRAFANA_ADMIN_USER"
            "GRAFANA_ADMIN_PASSWORD"
        )
        
        local content=$(cat "${PROJECT_DIR}/.env")
        local missing=0
        local missing_vars=""
        
        for var in "${required_vars[@]}"; do
            if ! echo "$content" | grep -q "^${var}="; then
                missing=$((missing + 1))
                missing_vars="${missing_vars} ${var}"
            fi
        done
        
        if [ $missing -eq 0 ]; then
            test_pass "Environment file contains all required variables"
        else
            test_fail "Environment variables" "Missing:${missing_vars}"
        fi
    else
        test_fail "Environment file exists" ".env not found"
    fi
}

test_port_values_valid() {
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env"
        
        local ports=(
            "${DASHBOARD_PORT:-}"
            "${PORTAINER_PORT:-}"
            "${JENKINS_PORT:-}"
            "${GRAFANA_PORT:-}"
            "${PROMETHEUS_PORT:-}"
        )
        
        local invalid=0
        for port in "${ports[@]}"; do
            if [ -n "$port" ]; then
                if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                    invalid=$((invalid + 1))
                fi
            fi
        done
        
        if [ $invalid -eq 0 ]; then
            test_pass "All port values are valid numbers (1-65535)"
        else
            test_fail "Port validation" "${invalid} invalid port value(s)"
        fi
    else
        test_fail "Port validation" ".env not found"
    fi
}

# =============================================================================
# DOCKER COMPOSE VALIDATION
# =============================================================================

test_docker_compose_structure() {
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/docker-compose.yml")
        
        # Check for required sections
        local has_services=$(echo "$content" | grep -c "^services:" || true)
        local has_networks=$(echo "$content" | grep -c "^networks:" || true)
        
        if [ "$has_services" -gt 0 ] && [ "$has_networks" -gt 0 ]; then
            test_pass "docker-compose.yml has required structure (services, networks)"
        else
            test_fail "docker-compose.yml structure" "Missing services or networks section"
        fi
    else
        test_fail "docker-compose.yml structure" "File not found"
    fi
}

test_docker_compose_services() {
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local expected_services=(
            "dashboard"
            "portainer"
            "jenkins"
            "grafana"
            "prometheus"
        )
        
        local content=$(cat "${PROJECT_DIR}/docker-compose.yml")
        local missing=0
        local missing_services=""
        
        for svc in "${expected_services[@]}"; do
            if ! echo "$content" | grep -q "^  ${svc}:"; then
                missing=$((missing + 1))
                missing_services="${missing_services} ${svc}"
            fi
        done
        
        if [ $missing -eq 0 ]; then
            test_pass "docker-compose.yml defines all core services"
        else
            test_fail "docker-compose.yml services" "Missing:${missing_services}"
        fi
    else
        test_fail "docker-compose.yml services" "File not found"
    fi
}

# =============================================================================
# PACKAGE.JSON VALIDATION
# =============================================================================

test_package_json_structure() {
    if [ -f "${PROJECT_DIR}/dashboard/package.json" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/package.json")
        
        # Check required fields
        local has_name=$(echo "$content" | grep -c '"name"' || true)
        local has_main=$(echo "$content" | grep -c '"main"' || true)
        local has_deps=$(echo "$content" | grep -c '"dependencies"' || true)
        
        if [ "$has_name" -gt 0 ] && [ "$has_main" -gt 0 ] && [ "$has_deps" -gt 0 ]; then
            test_pass "package.json has required fields (name, main, dependencies)"
        else
            test_fail "package.json structure" "Missing required fields"
        fi
    else
        test_fail "package.json structure" "File not found"
    fi
}

test_package_json_dependencies() {
    if [ -f "${PROJECT_DIR}/dashboard/package.json" ]; then
        local required_deps=("express" "dockerode" "ws")
        local content=$(cat "${PROJECT_DIR}/dashboard/package.json")
        local missing=0
        
        for dep in "${required_deps[@]}"; do
            if ! echo "$content" | grep -q "\"${dep}\""; then
                missing=$((missing + 1))
            fi
        done
        
        if [ $missing -eq 0 ]; then
            test_pass "package.json has required dependencies"
        else
            test_fail "package.json dependencies" "${missing} dependencies missing"
        fi
    else
        test_fail "package.json dependencies" "File not found"
    fi
}

# =============================================================================
# HTML/CSS VALIDATION
# =============================================================================

test_html_structure() {
    if [ -f "${PROJECT_DIR}/dashboard/public/index.html" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/public/index.html")
        
        local has_doctype=$(echo "$content" | grep -ci "<!DOCTYPE html>" || true)
        local has_html=$(echo "$content" | grep -c "<html" || true)
        local has_head=$(echo "$content" | grep -c "<head>" || true)
        local has_body=$(echo "$content" | grep -c "<body>" || true)
        
        if [ "$has_doctype" -gt 0 ] && [ "$has_html" -gt 0 ] && [ "$has_head" -gt 0 ] && [ "$has_body" -gt 0 ]; then
            test_pass "index.html has valid HTML structure"
        else
            test_fail "index.html structure" "Missing DOCTYPE, html, head, or body"
        fi
    else
        test_fail "index.html structure" "File not found"
    fi
}

test_css_not_empty() {
    if [ -f "${PROJECT_DIR}/dashboard/public/styles.css" ]; then
        local line_count=$(wc -l < "${PROJECT_DIR}/dashboard/public/styles.css")
        
        if [ "$line_count" -gt 50 ]; then
            test_pass "styles.css has substantial content (${line_count} lines)"
        else
            test_fail "styles.css content" "File seems too small (${line_count} lines)"
        fi
    else
        test_fail "styles.css content" "File not found"
    fi
}

# =============================================================================
# SECURITY CHECKS
# =============================================================================

test_no_hardcoded_secrets() {
    local files_to_check=(
        "dashboard/server.js"
        "dashboard/public/app.js"
        "context/jenkins/init.groovy.d/02-create-admin.groovy"
    )
    
    local found_secrets=0
    
    for file in "${files_to_check[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            # Check for common hardcoded secret patterns (excluding env var references)
            if grep -E "(password|secret|key)\s*[:=]\s*['\"][^\$\{]" "${PROJECT_DIR}/${file}" 2>/dev/null | grep -v "getenv\|process\.env\|System\.getenv" | grep -q .; then
                found_secrets=$((found_secrets + 1))
            fi
        fi
    done
    
    if [ $found_secrets -eq 0 ]; then
        test_pass "No hardcoded secrets found in source files"
    else
        test_fail "Hardcoded secrets check" "Found potential hardcoded secrets in ${found_secrets} file(s)"
    fi
}

# =============================================================================
# NEW FEATURE TESTS
# =============================================================================

test_service_categories() {
    if [ -f "${PROJECT_DIR}/dashboard/server.js" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/server.js")
        
        # Check for category definitions
        local has_categories=$(echo "$content" | grep -c "const categories" || true)
        local has_cicd=$(echo "$content" | grep -c "category: 'cicd'" || true)
        local has_monitoring=$(echo "$content" | grep -c "category: 'monitoring'" || true)
        local has_infra=$(echo "$content" | grep -c "category: 'infra'" || true)
        
        if [ "$has_categories" -gt 0 ] && [ "$has_cicd" -gt 0 ] && [ "$has_monitoring" -gt 0 ] && [ "$has_infra" -gt 0 ]; then
            test_pass "Service categories are properly defined"
        else
            test_fail "Service categories" "Missing category definitions"
        fi
    else
        test_fail "Service categories" "server.js not found"
    fi
}

test_nexus_configuration() {
    if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
        local content=$(cat "${PROJECT_DIR}/docker-compose.yml")
        
        # Check for Nexus service
        local has_nexus=$(echo "$content" | grep -c "nexus:" || true)
        local has_sonatype=$(echo "$content" | grep -c "sonatype/nexus3" || true)
        
        if [ "$has_nexus" -gt 0 ] && [ "$has_sonatype" -gt 0 ]; then
            test_pass "Nexus Repository Manager is configured"
        else
            test_fail "Nexus configuration" "Nexus service not found in docker-compose.yml"
        fi
    else
        test_fail "Nexus configuration" "docker-compose.yml not found"
    fi
}

test_shell_access_flags() {
    if [ -f "${PROJECT_DIR}/dashboard/server.js" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/server.js")
        
        # Check for shell property (bash, sh, or null)
        local has_shell_bash=$(echo "$content" | grep -c "shell: 'bash'" || true)
        local has_shell_sh=$(echo "$content" | grep -c "shell: 'sh'" || true)
        local has_shell_null=$(echo "$content" | grep -c "shell: null" || true)
        
        if [ "$has_shell_bash" -gt 0 ] && [ "$has_shell_sh" -gt 0 ] && [ "$has_shell_null" -gt 0 ]; then
            test_pass "Shell access flags are defined for services"
        else
            test_fail "Shell access flags" "Missing shell definitions (bash, sh, null)"
        fi
    else
        test_fail "Shell access flags" "server.js not found"
    fi
}

test_category_css_styles() {
    if [ -f "${PROJECT_DIR}/dashboard/public/styles.css" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/public/styles.css")
        
        # Check for category styles
        local has_section=$(echo "$content" | grep -c ".category-section" || true)
        local has_header=$(echo "$content" | grep -c ".category-header" || true)
        local has_services=$(echo "$content" | grep -c ".category-services" || true)
        
        if [ "$has_section" -gt 0 ] && [ "$has_header" -gt 0 ] && [ "$has_services" -gt 0 ]; then
            test_pass "Category CSS styles are defined"
        else
            test_fail "Category CSS styles" "Missing category style definitions"
        fi
    else
        test_fail "Category CSS styles" "styles.css not found"
    fi
}

test_logo_is_clickable() {
    if [ -f "${PROJECT_DIR}/dashboard/public/index.html" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/public/index.html")
        
        # Check logo is an anchor tag
        local has_logo_link=$(echo "$content" | grep -c '<a href="http://localhost:9900/".*class="logo"' || true)
        
        if [ "$has_logo_link" -gt 0 ]; then
            test_pass "Logo is clickable and links to dashboard home"
        else
            test_fail "Logo clickable" "Logo should be an anchor tag linking to dashboard"
        fi
    else
        test_fail "Logo clickable" "index.html not found"
    fi
}

test_grafana_dashboard_queries() {
    if [ -f "${PROJECT_DIR}/config/grafana/dashboards/docker-containers.json" ]; then
        local content=$(cat "${PROJECT_DIR}/config/grafana/dashboards/docker-containers.json")
        
        # Check for proper Prometheus queries
        local has_docker_query=$(echo "$content" | grep -c 'container_memory_usage_bytes' || true)
        local has_prometheus_uid=$(echo "$content" | grep -c '"uid": "prometheus"' || true)
        
        if [ "$has_docker_query" -gt 0 ] && [ "$has_prometheus_uid" -gt 0 ]; then
            test_pass "Grafana dashboard has proper container queries"
        else
            test_fail "Grafana queries" "Dashboard missing container memory queries"
        fi
    else
        test_fail "Grafana queries" "docker-containers.json not found"
    fi
}

test_categories_endpoint() {
    if [ -f "${PROJECT_DIR}/dashboard/server.js" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/server.js")
        
        # Check for categories API endpoint
        local has_endpoint=$(echo "$content" | grep -c "app.get('/api/categories'" || true)
        
        if [ "$has_endpoint" -gt 0 ]; then
            test_pass "Categories API endpoint is defined"
        else
            test_fail "Categories endpoint" "Missing /api/categories endpoint"
        fi
    else
        test_fail "Categories endpoint" "server.js not found"
    fi
}

# =============================================================================
# JENKINS GROOVY SCRIPT TESTS
# =============================================================================

test_jenkins_admin_script() {
    if [ -f "${PROJECT_DIR}/context/jenkins/init.groovy.d/02-create-admin.groovy" ]; then
        local content=$(cat "${PROJECT_DIR}/context/jenkins/init.groovy.d/02-create-admin.groovy")
        
        # Check for required elements
        local has_import=$(echo "$content" | grep -c "import jenkins.model" || true)
        local has_security=$(echo "$content" | grep -c "HudsonPrivateSecurityRealm" || true)
        local has_env=$(echo "$content" | grep -c "System.getenv" || true)
        
        if [ "$has_import" -gt 0 ] && [ "$has_security" -gt 0 ] && [ "$has_env" -gt 0 ]; then
            test_pass "Jenkins admin script has correct structure"
        else
            test_fail "Jenkins admin script" "Missing required Groovy elements"
        fi
    else
        test_fail "Jenkins admin script" "02-create-admin.groovy not found"
    fi
}

test_jenkins_pipeline_script() {
    if [ -f "${PROJECT_DIR}/context/jenkins/init.groovy.d/04-create-test-pipeline.groovy" ]; then
        local content=$(cat "${PROJECT_DIR}/context/jenkins/init.groovy.d/04-create-test-pipeline.groovy")
        
        # Check for required elements
        local has_import=$(echo "$content" | grep -c "import jenkins.model" || true)
        local has_workflow=$(echo "$content" | grep -c "WorkflowJob" || true)
        local has_pipeline=$(echo "$content" | grep -c "pipeline {" || true)
        local has_stages=$(echo "$content" | grep -c "stages {" || true)
        
        if [ "$has_import" -gt 0 ] && [ "$has_workflow" -gt 0 ] && [ "$has_pipeline" -gt 0 ] && [ "$has_stages" -gt 0 ]; then
            test_pass "Jenkins pipeline script has correct structure"
        else
            test_fail "Jenkins pipeline script" "Missing required pipeline elements"
        fi
    else
        test_fail "Jenkins pipeline script" "04-create-test-pipeline.groovy not found"
    fi
}

test_devopslab_script_commands() {
    if [ -f "${PROJECT_DIR}/devopslab.sh" ]; then
        local content=$(cat "${PROJECT_DIR}/devopslab.sh")
        
        # Check for required commands (help uses different pattern)
        local commands=("start" "stop" "restart" "status" "logs" "build" "info")
        local missing=0
        
        for cmd in "${commands[@]}"; do
            if ! echo "$content" | grep -q "^    ${cmd})"; then
                missing=$((missing + 1))
            fi
        done
        
        # Check help command with alternate pattern
        if ! echo "$content" | grep -q "help|--help|-h)"; then
            missing=$((missing + 1))
        fi
        
        if [ $missing -eq 0 ]; then
            test_pass "devopslab.sh has all required commands (8 commands)"
        else
            test_fail "devopslab.sh commands" "${missing} commands missing"
        fi
    else
        test_fail "devopslab.sh commands" "devopslab.sh not found"
    fi
}

test_devopslab_script_functions() {
    if [ -f "${PROJECT_DIR}/devopslab.sh" ]; then
        local content=$(cat "${PROJECT_DIR}/devopslab.sh")
        
        # Check for required functions
        local has_start=$(echo "$content" | grep -c "start_services()" || true)
        local has_stop=$(echo "$content" | grep -c "stop_services()" || true)
        local has_info=$(echo "$content" | grep -c "print_info()" || true)
        
        if [ "$has_start" -gt 0 ] && [ "$has_stop" -gt 0 ] && [ "$has_info" -gt 0 ]; then
            test_pass "devopslab.sh has required function definitions"
        else
            test_fail "devopslab.sh functions" "Missing required functions"
        fi
    else
        test_fail "devopslab.sh functions" "devopslab.sh not found"
    fi
}

# =============================================================================
# RUN TESTS
# =============================================================================

test_start

echo -e "\n${YELLOW}📁 File Structure Tests${NC}"
test_required_files_exist

echo -e "\n${YELLOW}📝 Syntax Validation Tests${NC}"
test_yaml_syntax
test_json_syntax
test_javascript_syntax
test_shell_syntax
test_dockerfile_syntax

echo -e "\n${YELLOW}⚙️ Configuration Tests${NC}"
test_env_template
test_port_values_valid
test_docker_compose_structure
test_docker_compose_services

echo -e "\n${YELLOW}📦 Package Tests${NC}"
test_package_json_structure
test_package_json_dependencies

echo -e "\n${YELLOW}🎨 Frontend Tests${NC}"
test_html_structure
test_css_not_empty

echo -e "\n${YELLOW}🔒 Security Tests${NC}"
test_no_hardcoded_secrets

echo -e "\n${YELLOW}🆕 New Feature Tests${NC}"
test_service_categories
test_nexus_configuration
test_shell_access_flags
test_category_css_styles
test_logo_is_clickable
test_grafana_dashboard_queries
test_categories_endpoint

echo -e "\n${YELLOW}🔧 Jenkins Groovy Tests${NC}"
test_jenkins_admin_script
test_jenkins_pipeline_script

echo -e "\n${YELLOW}📜 Management Script Tests${NC}"
test_devopslab_script_commands
test_devopslab_script_functions

test_summary

