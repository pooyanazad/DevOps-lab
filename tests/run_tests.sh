#!/bin/bash
# =============================================================================
# DevOpsLab Test Runner
# Runs all tests and generates combined report
# =============================================================================

# Don't exit on first error
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           DevOpsLab Test Suite Runner                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_usage() {
    echo "Usage: $0 [unit|integration|smoke|all]"
    echo ""
    echo "  unit        - Run unit tests only"
    echo "  integration - Run integration tests only"
    echo "  smoke       - Run smoke tests only"
    echo "  all         - Run all tests (default)"
    echo ""
}

run_unit_tests() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Stage 1: UNIT TESTS                                       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    if bash "${SCRIPT_DIR}/unit_test.sh"; then
        echo -e "\n${GREEN}✓ Unit tests passed${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Unit tests failed${NC}"
        return 1
    fi
}

run_integration_tests() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Stage 2: INTEGRATION TESTS                                ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    if bash "${SCRIPT_DIR}/integration_test.sh"; then
        echo -e "\n${GREEN}✓ Integration tests passed${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Integration tests failed${NC}"
        return 1
    fi
}

run_smoke_tests() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Stage 3: SMOKE TESTS                                      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    if bash "${SCRIPT_DIR}/smoke_test.sh"; then
        echo -e "\n${GREEN}✓ Smoke tests passed${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Smoke tests failed${NC}"
        return 1
    fi
}

run_all_tests() {
    local failed=0
    
    run_unit_tests || failed=$((failed + 1))
    run_integration_tests || failed=$((failed + 1))
    run_smoke_tests || failed=$((failed + 1))
    
    # Generate HTML report
    if [ -f "${SCRIPT_DIR}/generate_html_report.sh" ]; then
        echo -e "\n${YELLOW}📄 Generating HTML Report...${NC}"
        bash "${SCRIPT_DIR}/generate_html_report.sh"
    fi
    
    echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  FINAL RESULTS                                             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    if [ $failed -eq 0 ]; then
        echo -e "\n  ${GREEN}🎉 All test stages passed!${NC}\n"
        return 0
    else
        echo -e "\n  ${RED}⚠️  ${failed} test stage(s) failed${NC}\n"
        return 1
    fi
}

# Create reports directory
mkdir -p "${SCRIPT_DIR}/reports"

# Make test scripts executable
chmod +x "${SCRIPT_DIR}/unit_test.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/integration_test.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/smoke_test.sh" 2>/dev/null || true

# Main
print_banner

case "${1:-all}" in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    smoke)
        run_smoke_tests
        ;;
    all)
        run_all_tests
        ;;
    -h|--help|help)
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        print_usage
        exit 1
        ;;
esac
