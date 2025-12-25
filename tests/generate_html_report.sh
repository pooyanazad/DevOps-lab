#!/bin/bash
# =============================================================================
# DevOpsLab Professional Test Report Generator
# Generates a comprehensive HTML report with detailed test breakdown
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
HTML_REPORT="${REPORTS_DIR}/test-report.html"

# Colors for terminal
GREEN='\033[0;32m'
NC='\033[0m'

# Create reports directory if not exists
mkdir -p "${REPORTS_DIR}"

# Parse XML and extract test counts
parse_xml() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        local tests=$(grep -oP 'tests="\K[^"]+' "$file" | head -1)
        local failures=$(grep -oP 'failures="\K[^"]+' "$file" | head -1)
        local passed=$((tests - failures))
        echo "${name}|${tests}|${passed}|${failures}"
    else
        echo "${name}|0|0|0"
    fi
}

# Get current timestamp
REPORT_DATE=$(date "+%B %d, %Y at %H:%M:%S")
REPORT_DATE_SHORT=$(date "+%Y-%m-%d %H:%M")

# Get git info if available
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")
GIT_AUTHOR=$(git log -1 --pretty=format:'%an' 2>/dev/null || echo "N/A")

# Get test results
UNIT=$(parse_xml "${REPORTS_DIR}/unit-results.xml" "Unit Tests")
INTEGRATION=$(parse_xml "${REPORTS_DIR}/integration-results.xml" "Integration Tests")
SMOKE=$(parse_xml "${REPORTS_DIR}/smoke-results.xml" "Smoke Tests")

# Calculate totals
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

for result in "$UNIT" "$INTEGRATION" "$SMOKE"; do
    tests=$(echo "$result" | cut -d'|' -f2)
    passed=$(echo "$result" | cut -d'|' -f3)
    failed=$(echo "$result" | cut -d'|' -f4)
    TOTAL_TESTS=$((TOTAL_TESTS + tests))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
done

# Calculate pass rate
if [ "$TOTAL_TESTS" -gt 0 ]; then
    PASS_RATE=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
else
    PASS_RATE=0
fi

# Determine overall status
if [ "$TOTAL_FAILED" -eq 0 ]; then
    OVERALL_STATUS="PASSED"
    STATUS_CLASS="success"
    STATUS_EMOJI="✅"
else
    OVERALL_STATUS="FAILED"
    STATUS_CLASS="danger"
    STATUS_EMOJI="❌"
fi

# Get individual stage data
UNIT_TESTS=$(echo "$UNIT" | cut -d'|' -f2)
UNIT_PASSED=$(echo "$UNIT" | cut -d'|' -f3)
UNIT_FAILED=$(echo "$UNIT" | cut -d'|' -f4)

INT_TESTS=$(echo "$INTEGRATION" | cut -d'|' -f2)
INT_PASSED=$(echo "$INTEGRATION" | cut -d'|' -f3)
INT_FAILED=$(echo "$INTEGRATION" | cut -d'|' -f4)

SMOKE_TESTS=$(echo "$SMOKE" | cut -d'|' -f2)
SMOKE_PASSED=$(echo "$SMOKE" | cut -d'|' -f3)
SMOKE_FAILED=$(echo "$SMOKE" | cut -d'|' -f4)

# Generate HTML
cat > "${HTML_REPORT}" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOpsLab Test Report</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-dark: #0d1117;
            --bg-card: #161b22;
            --bg-card-hover: #1c2129;
            --border-color: #30363d;
            --text-primary: #e6edf3;
            --text-secondary: #8b949e;
            --text-muted: #6e7681;
            --success: #3fb950;
            --success-bg: rgba(63, 185, 80, 0.1);
            --danger: #f85149;
            --danger-bg: rgba(248, 81, 73, 0.1);
            --warning: #d29922;
            --info: #58a6ff;
            --accent: #8b5cf6;
            --accent-light: rgba(139, 92, 246, 0.1);
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-dark);
            color: var(--text-primary);
            line-height: 1.6;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 24px;
        }
        
        /* Header */
        .header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 32px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--border-color);
        }
        
        .header-left h1 {
            font-size: 28px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }
        
        .header-left h1 .logo {
            width: 36px;
            height: 36px;
            background: linear-gradient(135deg, var(--accent), #ec4899);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        }
        
        .header-left p {
            color: var(--text-secondary);
            font-size: 14px;
        }
        
        .header-right {
            text-align: right;
        }
        
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 10px 20px;
            border-radius: 24px;
            font-weight: 600;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .status-badge.success {
            background: var(--success-bg);
            color: var(--success);
            border: 1px solid var(--success);
        }
        
        .status-badge.danger {
            background: var(--danger-bg);
            color: var(--danger);
            border: 1px solid var(--danger);
        }
        
        /* Stats Grid */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
            margin-bottom: 32px;
        }
        
        .stat-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            text-align: center;
            transition: all 0.2s;
        }
        
        .stat-card:hover {
            background: var(--bg-card-hover);
            transform: translateY(-2px);
        }
        
        .stat-value {
            font-size: 42px;
            font-weight: 700;
            line-height: 1;
            margin-bottom: 8px;
        }
        
        .stat-value.success { color: var(--success); }
        .stat-value.danger { color: var(--danger); }
        .stat-value.info { color: var(--info); }
        .stat-value.accent { color: var(--accent); }
        
        .stat-label {
            font-size: 13px;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 1px;
            font-weight: 500;
        }
        
        /* Progress Ring */
        .progress-container {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 16px;
            margin-bottom: 8px;
        }
        
        .progress-ring {
            width: 80px;
            height: 80px;
            position: relative;
        }
        
        .progress-ring svg {
            transform: rotate(-90deg);
        }
        
        .progress-ring circle {
            fill: none;
            stroke-width: 8;
        }
        
        .progress-ring .bg {
            stroke: var(--border-color);
        }
        
        .progress-ring .progress {
            stroke: var(--success);
            stroke-linecap: round;
            transition: stroke-dashoffset 0.5s ease;
        }
        
        .progress-ring .percentage {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 18px;
            font-weight: 700;
        }
        
        /* Section Header */
        .section-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 20px;
            margin-top: 40px;
        }
        
        .section-header h2 {
            font-size: 20px;
            font-weight: 600;
        }
        
        .section-header .badge {
            font-size: 12px;
            padding: 4px 10px;
            border-radius: 12px;
            background: var(--accent-light);
            color: var(--accent);
            font-weight: 500;
        }
        
        /* Stage Cards */
        .stages-container {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }
        
        .stage-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            display: grid;
            grid-template-columns: auto 1fr auto;
            gap: 24px;
            align-items: center;
            transition: all 0.2s;
        }
        
        .stage-card:hover {
            background: var(--bg-card-hover);
            border-color: var(--accent);
        }
        
        .stage-icon {
            width: 56px;
            height: 56px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 28px;
        }
        
        .stage-icon.unit { background: linear-gradient(135deg, #3b82f6, #1d4ed8); }
        .stage-icon.integration { background: linear-gradient(135deg, #8b5cf6, #6d28d9); }
        .stage-icon.smoke { background: linear-gradient(135deg, #f59e0b, #d97706); }
        
        .stage-info h3 {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 4px;
        }
        
        .stage-info p {
            color: var(--text-secondary);
            font-size: 14px;
        }
        
        .stage-info .description {
            margin-top: 8px;
            font-size: 13px;
            color: var(--text-muted);
        }
        
        .stage-results {
            display: flex;
            gap: 32px;
            align-items: center;
        }
        
        .result-item {
            text-align: center;
        }
        
        .result-value {
            font-size: 24px;
            font-weight: 700;
        }
        
        .result-label {
            font-size: 11px;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .stage-status {
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .stage-status.pass {
            background: var(--success-bg);
            color: var(--success);
        }
        
        .stage-status.fail {
            background: var(--danger-bg);
            color: var(--danger);
        }
        
        /* Meta Info */
        .meta-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 16px;
            margin-top: 40px;
        }
        
        .meta-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
        }
        
        .meta-card h4 {
            font-size: 12px;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        
        .meta-card p {
            font-size: 14px;
            font-weight: 500;
            word-break: break-all;
        }
        
        .meta-card .icon {
            margin-right: 8px;
        }
        
        /* Footer */
        .footer {
            margin-top: 48px;
            padding-top: 24px;
            border-top: 1px solid var(--border-color);
            text-align: center;
            color: var(--text-muted);
            font-size: 13px;
        }
        
        .footer a {
            color: var(--info);
            text-decoration: none;
        }
        
        /* Pipeline Visualization */
        .pipeline {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            margin: 32px 0;
            padding: 24px;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
        }
        
        .pipeline-stage {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .pipeline-node {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            border: 3px solid;
        }
        
        .pipeline-node.pass {
            background: var(--success-bg);
            border-color: var(--success);
        }
        
        .pipeline-node.fail {
            background: var(--danger-bg);
            border-color: var(--danger);
        }
        
        .pipeline-arrow {
            color: var(--text-muted);
            font-size: 24px;
        }
        
        .pipeline-label {
            font-size: 12px;
            color: var(--text-secondary);
            text-align: center;
            margin-top: 8px;
        }
        
        @media (max-width: 768px) {
            .stats-grid {
                grid-template-columns: repeat(2, 1fr);
            }
            
            .stage-card {
                grid-template-columns: 1fr;
                text-align: center;
            }
            
            .stage-results {
                justify-content: center;
            }
            
            .meta-grid {
                grid-template-columns: 1fr;
            }
            
            .header {
                flex-direction: column;
                gap: 16px;
            }
            
            .header-right {
                text-align: left;
            }
            
            .pipeline {
                flex-wrap: wrap;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <header class="header">
            <div class="header-left">
                <h1>
                    <span class="logo">🧪</span>
                    DevOpsLab Test Report
                </h1>
                <p>Generated on REPORT_DATE</p>
            </div>
            <div class="header-right">
                <span class="status-badge STATUS_CLASS">
                    STATUS_EMOJI OVERALL_STATUS
                </span>
            </div>
        </header>
        
        <!-- Stats Grid -->
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value info">TOTAL_TESTS</div>
                <div class="stat-label">Total Tests</div>
            </div>
            <div class="stat-card">
                <div class="stat-value success">TOTAL_PASSED</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat-card">
                <div class="stat-value danger">TOTAL_FAILED</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-card">
                <div class="progress-container">
                    <div class="progress-ring">
                        <svg width="80" height="80">
                            <circle class="bg" cx="40" cy="40" r="32"/>
                            <circle class="progress" cx="40" cy="40" r="32" 
                                stroke-dasharray="201" 
                                stroke-dashoffset="PROGRESS_OFFSET"/>
                        </svg>
                        <span class="percentage">PASS_RATE%</span>
                    </div>
                </div>
                <div class="stat-label">Pass Rate</div>
            </div>
        </div>
        
        <!-- Pipeline Visualization -->
        <div class="pipeline">
            <div class="pipeline-stage">
                <div>
                    <div class="pipeline-node UNIT_STATUS">📋</div>
                    <div class="pipeline-label">Unit</div>
                </div>
            </div>
            <span class="pipeline-arrow">→</span>
            <div class="pipeline-stage">
                <div>
                    <div class="pipeline-node INT_STATUS">🔗</div>
                    <div class="pipeline-label">Integration</div>
                </div>
            </div>
            <span class="pipeline-arrow">→</span>
            <div class="pipeline-stage">
                <div>
                    <div class="pipeline-node SMOKE_STATUS">🔥</div>
                    <div class="pipeline-label">Smoke</div>
                </div>
            </div>
            <span class="pipeline-arrow">→</span>
            <div class="pipeline-stage">
                <div>
                    <div class="pipeline-node FINAL_STATUS">🚀</div>
                    <div class="pipeline-label">Deploy Ready</div>
                </div>
            </div>
        </div>
        
        <!-- Test Stages -->
        <div class="section-header">
            <h2>📊 Test Stages</h2>
            <span class="badge">3 Stages</span>
        </div>
        
        <div class="stages-container">
            <!-- Unit Tests -->
            <div class="stage-card">
                <div class="stage-icon unit">📋</div>
                <div class="stage-info">
                    <h3>Stage 1: Unit Tests</h3>
                    <p>UNIT_TESTS tests executed</p>
                    <div class="description">Code syntax validation, file structure, configuration checks, and security scans</div>
                </div>
                <div class="stage-results">
                    <div class="result-item">
                        <div class="result-value success">UNIT_PASSED</div>
                        <div class="result-label">Passed</div>
                    </div>
                    <div class="result-item">
                        <div class="result-value danger">UNIT_FAILED</div>
                        <div class="result-label">Failed</div>
                    </div>
                    <span class="stage-status UNIT_STATUS">UNIT_STATUS_TEXT</span>
                </div>
            </div>
            
            <!-- Integration Tests -->
            <div class="stage-card">
                <div class="stage-icon integration">🔗</div>
                <div class="stage-info">
                    <h3>Stage 2: Integration Tests</h3>
                    <p>INT_TESTS tests executed</p>
                    <div class="description">Component integration, API validation, service connectivity, and Docker configuration</div>
                </div>
                <div class="stage-results">
                    <div class="result-item">
                        <div class="result-value success">INT_PASSED</div>
                        <div class="result-label">Passed</div>
                    </div>
                    <div class="result-item">
                        <div class="result-value danger">INT_FAILED</div>
                        <div class="result-label">Failed</div>
                    </div>
                    <span class="stage-status INT_STATUS">INT_STATUS_TEXT</span>
                </div>
            </div>
            
            <!-- Smoke Tests -->
            <div class="stage-card">
                <div class="stage-icon smoke">🔥</div>
                <div class="stage-info">
                    <h3>Stage 3: Smoke Tests</h3>
                    <p>SMOKE_TESTS tests executed</p>
                    <div class="description">Deployment readiness, documentation, security checks, and dependency validation</div>
                </div>
                <div class="stage-results">
                    <div class="result-item">
                        <div class="result-value success">SMOKE_PASSED</div>
                        <div class="result-label">Passed</div>
                    </div>
                    <div class="result-item">
                        <div class="result-value danger">SMOKE_FAILED</div>
                        <div class="result-label">Failed</div>
                    </div>
                    <span class="stage-status SMOKE_STATUS">SMOKE_STATUS_TEXT</span>
                </div>
            </div>
        </div>
        
        <!-- Build Information -->
        <div class="section-header">
            <h2>📝 Build Information</h2>
        </div>
        
        <div class="meta-grid">
            <div class="meta-card">
                <h4>🌿 Branch</h4>
                <p>GIT_BRANCH</p>
            </div>
            <div class="meta-card">
                <h4>📦 Commit</h4>
                <p>GIT_COMMIT</p>
            </div>
            <div class="meta-card">
                <h4>👤 Author</h4>
                <p>GIT_AUTHOR</p>
            </div>
        </div>
        
        <!-- Footer -->
        <footer class="footer">
            <p>DevOpsLab CI/CD Pipeline • Generated by Automated Test Suite</p>
            <p style="margin-top: 8px;">Report generated on REPORT_DATE_SHORT</p>
        </footer>
    </div>
</body>
</html>
EOF

# Helper function for status
get_status() {
    if [ "$1" -eq 0 ]; then
        echo "pass"
    else
        echo "fail"
    fi
}

get_status_text() {
    if [ "$1" -eq 0 ]; then
        echo "✓ Pass"
    else
        echo "✗ Fail"
    fi
}

# Calculate progress offset (circumference = 2 * PI * r = 201)
PROGRESS_OFFSET=$((201 - (201 * PASS_RATE / 100)))

# Get status classes
UNIT_STATUS_CLASS=$(get_status $UNIT_FAILED)
INT_STATUS_CLASS=$(get_status $INT_FAILED)
SMOKE_STATUS_CLASS=$(get_status $SMOKE_FAILED)
FINAL_STATUS_CLASS=$(get_status $TOTAL_FAILED)

# Get status text
UNIT_STATUS_TEXT=$(get_status_text $UNIT_FAILED)
INT_STATUS_TEXT=$(get_status_text $INT_FAILED)
SMOKE_STATUS_TEXT=$(get_status_text $SMOKE_FAILED)

# Replace all placeholders (using | as delimiter to avoid conflicts with special chars)
sed -i "s|REPORT_DATE_SHORT|${REPORT_DATE_SHORT}|g" "${HTML_REPORT}"
sed -i "s|REPORT_DATE|${REPORT_DATE}|g" "${HTML_REPORT}"
sed -i "s|TOTAL_TESTS|${TOTAL_TESTS}|g" "${HTML_REPORT}"
sed -i "s|TOTAL_PASSED|${TOTAL_PASSED}|g" "${HTML_REPORT}"
sed -i "s|TOTAL_FAILED|${TOTAL_FAILED}|g" "${HTML_REPORT}"
sed -i "s|PASS_RATE|${PASS_RATE}|g" "${HTML_REPORT}"
sed -i "s|PROGRESS_OFFSET|${PROGRESS_OFFSET}|g" "${HTML_REPORT}"
sed -i "s|STATUS_EMOJI|${STATUS_EMOJI}|g" "${HTML_REPORT}"
sed -i "s|STATUS_CLASS|${STATUS_CLASS}|g" "${HTML_REPORT}"
sed -i "s|OVERALL_STATUS|${OVERALL_STATUS}|g" "${HTML_REPORT}"

# Unit test replacements
sed -i "s|UNIT_TESTS|${UNIT_TESTS}|g" "${HTML_REPORT}"
sed -i "s|UNIT_PASSED|${UNIT_PASSED}|g" "${HTML_REPORT}"
sed -i "s|UNIT_FAILED|${UNIT_FAILED}|g" "${HTML_REPORT}"
sed -i "s|UNIT_STATUS_TEXT|${UNIT_STATUS_TEXT}|g" "${HTML_REPORT}"
sed -i "s|UNIT_STATUS|${UNIT_STATUS_CLASS}|g" "${HTML_REPORT}"

# Integration test replacements
sed -i "s|INT_TESTS|${INT_TESTS}|g" "${HTML_REPORT}"
sed -i "s|INT_PASSED|${INT_PASSED}|g" "${HTML_REPORT}"
sed -i "s|INT_FAILED|${INT_FAILED}|g" "${HTML_REPORT}"
sed -i "s|INT_STATUS_TEXT|${INT_STATUS_TEXT}|g" "${HTML_REPORT}"
sed -i "s|INT_STATUS|${INT_STATUS_CLASS}|g" "${HTML_REPORT}"

# Smoke test replacements
sed -i "s|SMOKE_TESTS|${SMOKE_TESTS}|g" "${HTML_REPORT}"
sed -i "s|SMOKE_PASSED|${SMOKE_PASSED}|g" "${HTML_REPORT}"
sed -i "s|SMOKE_FAILED|${SMOKE_FAILED}|g" "${HTML_REPORT}"
sed -i "s|SMOKE_STATUS_TEXT|${SMOKE_STATUS_TEXT}|g" "${HTML_REPORT}"
sed -i "s|SMOKE_STATUS|${SMOKE_STATUS_CLASS}|g" "${HTML_REPORT}"

# Final status
sed -i "s|FINAL_STATUS|${FINAL_STATUS_CLASS}|g" "${HTML_REPORT}"

# Git info replacements
sed -i "s|GIT_BRANCH|${GIT_BRANCH}|g" "${HTML_REPORT}"
sed -i "s|GIT_COMMIT|${GIT_COMMIT}|g" "${HTML_REPORT}"
sed -i "s|GIT_AUTHOR|${GIT_AUTHOR}|g" "${HTML_REPORT}"

echo -e "${GREEN}✓ HTML report generated: ${HTML_REPORT}${NC}"
