#!/usr/bin/env bash
#
# Complete S3 Performance Test Suite with Automatic Report Generation
#
# This script:
# 1. Runs the complete warp benchmark suite
# 2. Generates performance charts and HTML report
# 3. Opens the report in your browser
#
# Usage:
#   ./run_and_report.sh [target]
#
# Example:
#   ./run_and_report.sh aws
#   ./run_and_report.sh          # defaults to 'aws'
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
TARGET="${1:-aws}"
VENV_DIR=".venv"
BENCHMARK_SCRIPT="./warp_s3_benchmark.sh"
REPORT_SCRIPT="./report.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    print_header "S3 Performance Test Suite with Auto-Report"
    
    log_info "Target: $TARGET"
    log_info "Benchmark script: $BENCHMARK_SCRIPT"
    log_info "Report script: $REPORT_SCRIPT"
    echo ""
    
    # Step 1: Activate Python virtual environment
    if [[ ! -d "$VENV_DIR" ]]; then
        log_error "Virtual environment not found at $VENV_DIR"
        log_info "Please create it first with: python3 -m venv $VENV_DIR"
        exit 1
    fi
    
    log_info "Activating Python virtual environment..."
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    log_success "Virtual environment activated"
    echo ""
    
    # Step 2: Run benchmarks
    print_header "Step 1/2: Running Performance Benchmarks"
    
    if [[ ! -f "$BENCHMARK_SCRIPT" ]]; then
        log_error "Benchmark script not found: $BENCHMARK_SCRIPT"
        exit 1
    fi
    
    log_info "Starting benchmark suite..."
    # Force the full-run to focus on the Splunk S2 bucket size (majority of tests use 750MiB)
    export SIZES="750MiB"
    log_info "This full benchmark run will prioritize size: $SIZES (majority of tests)"
    echo ""
    
    # Run benchmark with --target flag
    # Safety: prompt before running large data transfer workloads (750MiB)
    if [[ "${SIZES:-}" == *"750MiB"* ]]; then
        # Allow CI / scripted runs to bypass prompt by setting RUN_WITHOUT_CONFIRM=1
        if [[ "${RUN_WITHOUT_CONFIRM:-0}" != "1" ]]; then
            if [[ -t 0 ]]; then
                log_warning "SIZES contains 750MiB which will perform large data transfers."
                echo "To proceed, type 'yes' (without quotes) and press Enter. To abort, press Enter or Ctrl+C."
                read -r CONFIRMATION
                if [[ "${CONFIRMATION}" != "yes" ]]; then
                    log_error "Aborting full benchmark run (user did not confirm)."
                    exit 1
                fi
            else
                log_error "Non-interactive shell detected and RUN_WITHOUT_CONFIRM != 1. Aborting to avoid large data transfers."
                exit 1
            fi
        else
            log_warning "RUN_WITHOUT_CONFIRM=1 detected — skipping interactive confirmation."
        fi
    fi

    if bash "$BENCHMARK_SCRIPT" --target "$TARGET"; then
        log_success "Benchmarks completed successfully!"
    else
        log_error "Benchmark execution failed!"
        exit 1
    fi
    
    echo ""
    
    # Step 3: Find the latest results directory
    RESULTS_BASE="results/$TARGET"
    if [[ ! -d "$RESULTS_BASE" ]]; then
        log_error "Results directory not found: $RESULTS_BASE"
        exit 1
    fi
    
    LATEST_RESULTS=$(ls -td "$RESULTS_BASE"/20* 2>/dev/null | head -1)
    if [[ -z "$LATEST_RESULTS" ]]; then
        log_error "No results found in $RESULTS_BASE"
        exit 1
    fi
    
    log_info "Latest results directory: $LATEST_RESULTS"
    
    # Check if summary.json exists
    SUMMARY_FILE="$LATEST_RESULTS/summary.json"
    if [[ ! -f "$SUMMARY_FILE" ]]; then
        log_error "Summary file not found: $SUMMARY_FILE"
        exit 1
    fi
    
    # Step 4: Generate report
    print_header "Step 2/2: Generating Performance Report"
    
    if [[ ! -f "$REPORT_SCRIPT" ]]; then
        log_error "Report script not found: $REPORT_SCRIPT"
        exit 1
    fi
    
    log_info "Generating charts and HTML report..."
    if python "$REPORT_SCRIPT" "$SUMMARY_FILE"; then
        log_success "Report generated successfully!"
    else
        log_warning "Report generation completed with warnings (this is OK if there's partial data)"
    fi
    
    echo ""
    
    # Step 5: Display results summary
    print_header "Results Summary"
    
    # Count successful tests
    TOTAL_TESTS=$(jq '.tests | length' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    SUCCESSFUL_TESTS=$(jq '[.tests[] | select(.errors == 0)] | length' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    FAILED_TESTS=$(jq '[.tests[] | select(.errors > 0)] | length' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    
    log_info "Total tests run: $TOTAL_TESTS"
    log_success "Successful tests: $SUCCESSFUL_TESTS"
    if [[ "$FAILED_TESTS" -gt 0 ]]; then
        log_warning "Failed tests: $FAILED_TESTS"
    fi
    echo ""
    
    # Find generated files
    REPORT_HTML="$LATEST_RESULTS/report.html"
    CHARTS_DIR="$LATEST_RESULTS/charts"
    
    if [[ -f "$REPORT_HTML" ]]; then
        log_success "HTML Report: $REPORT_HTML"
    fi
    
    if [[ -d "$CHARTS_DIR" ]]; then
        CHART_COUNT=$(find "$CHARTS_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
        log_success "Generated $CHART_COUNT charts in: $CHARTS_DIR"
    fi
    
    echo ""
    
    # Step 6: Show key metrics
    print_header "Key Performance Metrics"
    
    log_info "PUT Performance:"
    jq -r '.tests[] | select(.operation == "put") | "  \(.size) @ \(.concurrency) concurrent: \(.throughput_mbps) MB/s (\(.errors) errors)"' "$SUMMARY_FILE" 2>/dev/null || log_warning "No PUT metrics available"
    
    echo ""
    log_info "GET Performance:"
    jq -r '.tests[] | select(.operation == "get") | "  \(.size) @ \(.concurrency) concurrent: \(.throughput_mbps) MB/s (\(.errors) errors)"' "$SUMMARY_FILE" 2>/dev/null || log_warning "No GET metrics available"
    
    echo ""
    log_info "DELETE Performance:"
    jq -r '.tests[] | select(.operation == "delete") | "  \(.size) @ \(.concurrency) concurrent: \(.throughput_mbps) MB/s (\(.errors) errors)"' "$SUMMARY_FILE" 2>/dev/null || log_warning "No DELETE metrics available"
    
    echo ""
    log_info "LIST Performance:"
    jq -r '.tests[] | select(.operation == "list") | "  \(.size) @ \(.concurrency) concurrent: \(.ops_per_sec) ops/sec (\(.errors) errors)"' "$SUMMARY_FILE" 2>/dev/null || log_warning "No LIST metrics available"
    
    echo ""
    
    # Step 7: Open report in browser
    print_header "Opening Report"
    
    if [[ -f "$REPORT_HTML" ]]; then
        log_info "Opening report in your default browser..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            open "$REPORT_HTML"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v xdg-open &> /dev/null; then
                xdg-open "$REPORT_HTML"
            elif command -v gnome-open &> /dev/null; then
                gnome-open "$REPORT_HTML"
            else
                log_warning "Could not open browser automatically. Please open: $REPORT_HTML"
            fi
        else
            log_warning "Could not open browser automatically. Please open: $REPORT_HTML"
        fi
        
        log_success "Report is ready!"
    else
        log_warning "Report HTML not found, but results are available in: $LATEST_RESULTS"
    fi
    
    echo ""
    print_header "Complete!"
    
    echo "Results location: $LATEST_RESULTS"
    echo "Summary JSON: $SUMMARY_FILE"
    if [[ -f "$REPORT_HTML" ]]; then
        echo "HTML Report: $REPORT_HTML"
    fi
    echo ""
    
    log_success "All done! 🎉"
    echo ""
}

# Run main function
main "$@"
