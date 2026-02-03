#!/usr/bin/env bash
#
# quick_test.sh - Fast smoke test for S3 performance (takes ~2 minutes total)
#
# Usage:
#   ./quick_test.sh
#   ./quick_test.sh aws
#   ./quick_test.sh other
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-aws}"

echo "=========================================="
echo "Quick S3 Performance Test"
echo "=========================================="
echo ""
echo "Target: $TARGET"
echo "Duration: 10s per test"
echo "Total time: ~2 minutes"
echo ""

# Activate venv if it exists
if [ -d "${SCRIPT_DIR}/.venv" ]; then
    echo "✓ Activating Python virtual environment..."
    source "${SCRIPT_DIR}/.venv/bin/activate"
else
    echo "⚠ No venv found. Graphs may not work."
    echo "  Create one with: python3 -m venv .venv && source .venv/bin/activate && pip install matplotlib pandas jinja2 seaborn"
    echo ""
fi

# Run quick benchmark
echo "Running quick benchmark..."
echo ""

"${SCRIPT_DIR}/warp_s3_benchmark.sh" \
    --target "$TARGET" \
    --duration 10s \
    --warmup 2s \
    --sizes 1MiB \
    --concurrency 8 \
    --heartbeat-interval 5

echo ""
echo "=========================================="
echo "Benchmark Complete!"
echo "=========================================="
echo ""

# Find the latest results directory
LATEST_RESULT=$(find "${SCRIPT_DIR}/results/${TARGET}" -maxdepth 1 -type d | sort -r | head -2 | tail -1)

if [ -z "$LATEST_RESULT" ]; then
    echo "ERROR: No results found"
    exit 1
fi

echo "Results directory: $LATEST_RESULT"
echo ""

# Generate report with graphs
echo "Generating graphs and report..."
echo ""

"${SCRIPT_DIR}/warp_s3_benchmark.sh" --report-last "$TARGET"

echo ""
echo "=========================================="
echo "✓ All Done!"
echo "=========================================="
echo ""
echo "View results:"
echo "  Report:  open $LATEST_RESULT/report.html"
echo "  Charts:  open $LATEST_RESULT/charts/"
echo "  Summary: cat $LATEST_RESULT/summary.json | jq ."
echo ""
echo "Quick stats:"
cat "$LATEST_RESULT/summary.json" | jq -r '.[] | select(.error == null) | "\(.operation) @ \(.obj_size): \(.throughput_mbs | tonumber | floor) MB/s, \(.ops_per_sec | tonumber | floor) ops/s, \(.avg_latency_ms | tonumber | floor)ms avg latency"' 2>/dev/null || echo "  (Install jq to see summary)"
echo ""
