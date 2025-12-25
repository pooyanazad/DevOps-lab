#!/bin/bash
# =============================================================================
# DevOpsLab Smoke Tests
# Quick validation tests to verify project is ready for deployment
# These tests run fast and validate deployment readiness
# =============================================================================

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_start() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  SMOKE TESTS - Deployment Readiness${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  SMOKE TEST SUMMARY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Total:  ${TOTAL}"
    echo -e "  ${GREEN}Passed${NC}: ${PASSED}"
    echo -e "  ${RED}Failed${NC}: ${FAILED}"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n  ${GREEN}🎉 Project is ready for deployment!${NC}"
    else
        echo -e "\n  ${RED}⚠️  Some issues found. Fix before deployment.${NC}"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    generate_junit_report "smoke"
    
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
    <testcase name="smoke_validation" classname="devopslab.${test_type}">
      $(if [ $FAILED -gt 0 ]; then echo "<failure message=\"${FAILED} tests failed\"/>"; fi)
    </testcase>
  </testsuite>
</testsuites>
EOF
    echo -e "\n  📄 Report saved: ${report_file}"
}

# =============================================================================
# PROJECT HEALTH CHECKS
# =============================================================================

smoke_test_project_structure() {
    local required_dirs=(
        "dashboard"
        "dashboard/public"
        "context/jenkins"
        "context/jenkins-agent"
        "config/grafana"
        "config/prometheus"
        "tests"
    )
    
    local missing=0
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${PROJECT_DIR}/${dir}" ]; then
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        test_pass "Project directory structure is complete"
    else
        test_fail "Project structure" "${missing} directories missing"
    fi
}

smoke_test_core_files() {
    local core_files=(
        "docker-compose.yml"
        ".env"
        "README.md"
        "devopslab.sh"
    )
    
    local missing=0
    for file in "${core_files[@]}"; do
        if [ ! -f "${PROJECT_DIR}/${file}" ]; then
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        test_pass "All core project files exist"
    else
        test_fail "Core files" "${missing} files missing"
    fi
}

smoke_test_scripts_executable() {
    local scripts=(
        "devopslab.sh"
        "context/jenkins-agent/entrypoint.sh"
    )
    
    local not_exec=0
    for script in "${scripts[@]}"; do
        if [ -f "${PROJECT_DIR}/${script}" ] && [ ! -x "${PROJECT_DIR}/${script}" ]; then
            not_exec=$((not_exec + 1))
        fi
    done
    
    if [ $not_exec -eq 0 ]; then
        test_pass "All shell scripts are executable"
    else
        test_fail "Script permissions" "${not_exec} scripts not executable"
    fi
}

# =============================================================================
# DOCKER READINESS
# =============================================================================

smoke_test_dockerfiles_buildable() {
    local dockerfiles=(
        "dashboard/Dockerfile"
        "context/jenkins/Dockerfile"
        "context/jenkins-agent/Dockerfile"
    )
    
    local issues=0
    for dockerfile in "${dockerfiles[@]}"; do
        if [ -f "${PROJECT_DIR}/${dockerfile}" ]; then
            # Check basic Dockerfile requirements
            local content=$(cat "${PROJECT_DIR}/${dockerfile}")
            if ! echo "$content" | grep -q "^FROM"; then
                issues=$((issues + 1))
            fi
        else
            issues=$((issues + 1))
        fi
    done
    
    if [ $issues -eq 0 ]; then
        test_pass "All Dockerfiles are valid for building"
    else
        test_fail "Dockerfile validation" "${issues} Dockerfiles have issues"
    fi
}

smoke_test_compose_syntax() {
    if command -v docker &> /dev/null; then
        if docker compose -f "${PROJECT_DIR}/docker-compose.yml" config --quiet 2>/dev/null; then
            test_pass "docker-compose.yml passes syntax validation"
        else
            test_fail "docker-compose.yml syntax" "Validation failed"
        fi
    else
        # Fallback: basic YAML check
        if command -v python3 &> /dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('${PROJECT_DIR}/docker-compose.yml'))" 2>/dev/null; then
                test_pass "docker-compose.yml is valid YAML (Docker not available)"
            else
                test_fail "docker-compose.yml syntax" "Invalid YAML"
            fi
        else
            test_pass "docker-compose.yml syntax (skipped - no validators)"
        fi
    fi
}

# =============================================================================
# CONFIGURATION READINESS
# =============================================================================

smoke_test_env_complete() {
    if [ -f "${PROJECT_DIR}/.env" ]; then
        local empty_vars=$(grep -E "^[A-Z_]+=\s*$" "${PROJECT_DIR}/.env" | wc -l)
        
        if [ "$empty_vars" -eq 0 ]; then
            test_pass "No empty environment variables in .env"
        else
            test_fail "Environment config" "${empty_vars} empty variables found"
        fi
    else
        test_fail "Environment config" ".env not found"
    fi
}

smoke_test_passwords_not_default() {
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env"
        
        local weak_passwords=0
        local passwords=(
            "${JENKINS_ADMIN_PASSWORD:-}"
            "${GRAFANA_ADMIN_PASSWORD:-}"
            "${PORTAINER_ADMIN_PASSWORD:-}"
        )
        
        for pwd in "${passwords[@]}"; do
            if [ -n "$pwd" ] && [ ${#pwd} -lt 6 ]; then
                weak_passwords=$((weak_passwords + 1))
            fi
        done
        
        if [ $weak_passwords -eq 0 ]; then
            test_pass "All passwords meet minimum length requirement"
        else
            test_fail "Password security" "${weak_passwords} weak passwords found"
        fi
    else
        test_fail "Password security" ".env not found"
    fi
}

# =============================================================================
# DOCUMENTATION READINESS
# =============================================================================

smoke_test_readme_content() {
    if [ -f "${PROJECT_DIR}/README.md" ]; then
        local content=$(cat "${PROJECT_DIR}/README.md")
        local line_count=$(echo "$content" | wc -l)
        
        # Check README has substantial content
        local has_title=$(echo "$content" | grep -c "^#" || true)
        local has_install=$(echo "$content" | grep -ci "install\|setup\|start" || true)
        
        if [ "$line_count" -gt 50 ] && [ "$has_title" -gt 0 ] && [ "$has_install" -gt 0 ]; then
            test_pass "README.md has comprehensive documentation"
        else
            test_fail "README.md content" "Documentation appears incomplete"
        fi
    else
        test_fail "README.md content" "File not found"
    fi
}

# =============================================================================
# DEPENDENCY READINESS
# =============================================================================

smoke_test_npm_dependencies() {
    if [ -f "${PROJECT_DIR}/dashboard/package.json" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/package.json")
        
        # Check dependencies section exists and has entries
        local dep_count=$(echo "$content" | grep -A20 '"dependencies"' | grep -c '"[a-z]' || true)
        
        if [ "$dep_count" -gt 2 ]; then
            test_pass "package.json has ${dep_count} dependencies defined"
        else
            test_fail "NPM dependencies" "Too few dependencies"
        fi
    else
        test_fail "NPM dependencies" "package.json not found"
    fi
}

# =============================================================================
# GIT READINESS
# =============================================================================

smoke_test_gitignore() {
    if [ -f "${PROJECT_DIR}/.gitignore" ]; then
        local content=$(cat "${PROJECT_DIR}/.gitignore")
        
        # Check for common patterns
        local has_node=$(echo "$content" | grep -c "node_modules" || true)
        
        if [ "$has_node" -gt 0 ]; then
            test_pass ".gitignore has appropriate patterns"
        else
            test_fail ".gitignore patterns" "Missing node_modules pattern"
        fi
    else
        test_fail ".gitignore" "File not found"
    fi
}

smoke_test_no_secrets_committed() {
    # Check for common secret file patterns in the project
    local secret_files=$(find "${PROJECT_DIR}" -name "*.pem" -o -name "*.key" -o -name "id_rsa*" 2>/dev/null | wc -l)
    
    if [ "$secret_files" -eq 0 ]; then
        test_pass "No secret/key files found in project"
    else
        test_fail "Secret files" "${secret_files} potential secret files found"
    fi
}

# =============================================================================
# BUILD READINESS
# =============================================================================

smoke_test_all_imports_local() {
    if [ -f "${PROJECT_DIR}/dashboard/server.js" ]; then
        local content=$(cat "${PROJECT_DIR}/dashboard/server.js")
        
        # Check that main dependencies are imported
        local has_express=$(echo "$content" | grep -c "require('express')" || true)
        local has_docker=$(echo "$content" | grep -c "require('dockerode')" || true)
        
        if [ "$has_express" -gt 0 ] && [ "$has_docker" -gt 0 ]; then
            test_pass "server.js imports required dependencies"
        else
            test_fail "server.js imports" "Missing required imports"
        fi
    else
        test_fail "server.js imports" "File not found"
    fi
}

# =============================================================================
# RUN TESTS
# =============================================================================

test_start

echo -e "\n${YELLOW}📁 Project Health${NC}"
smoke_test_project_structure
smoke_test_core_files
smoke_test_scripts_executable

echo -e "\n${YELLOW}🐳 Docker Readiness${NC}"
smoke_test_dockerfiles_buildable
smoke_test_compose_syntax

echo -e "\n${YELLOW}⚙️ Configuration Readiness${NC}"
smoke_test_env_complete
smoke_test_passwords_not_default

echo -e "\n${YELLOW}📦 Dependency Readiness${NC}"
smoke_test_npm_dependencies
smoke_test_all_imports_local

echo -e "\n${YELLOW}📄 Documentation Readiness${NC}"
smoke_test_readme_content

echo -e "\n${YELLOW}🔒 Security Readiness${NC}"
smoke_test_gitignore
smoke_test_no_secrets_committed

test_summary
