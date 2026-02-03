#!/usr/bin/env bash
#
# Focused test: PUT and GET without warmup, short durations
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source target config
source targets/aws.env

echo "==========================================  "
echo "Focused S3 Performance Test (No Warmup)"
echo "=========================================="
echo ""

# Clean old results
RESULTS_DIR="results/aws/focused-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "✓ Results directory: $RESULTS_DIR"
echo ""

# Run PUT test
echo "Running PUT test (5s)..."
warp put \
  --host s3.us-east-2.amazonaws.com \
  --access-key "$S3_ACCESS_KEY" \
  --secret-key "$S3_SECRET_KEY" \
  --bucket "$S3_BUCKET" \
  --region "$S3_REGION" \
  --duration 5s \
  --obj.size 1MiB \
  --concurrent 8 \
  --prefix warp-bench/focused \
  --noclear \
  --autoterm \
  --json \
  > "$RESULTS_DIR/put.json"

echo "✓ PUT completed"
echo ""

# Extract PUT metrics
PUT_THROUGHPUT=$(jq -r '.total.throughput.bytes_per_sec // 0' "$RESULTS_DIR/put.json")
PUT_OBJECTS=$(jq -r '.total.total_objects // 0' "$RESULTS_DIR/put.json")
PUT_ERRORS=$(jq -r '.total.total_errors // 0' "$RESULTS_DIR/put.json")

echo "PUT Results:"
echo "  Objects: $PUT_OBJECTS"
echo "  Throughput: $(echo "scale=2; $PUT_THROUGHPUT / 1024 / 1024" | bc) MB/s"
echo "  Errors: $PUT_ERRORS"
echo ""

# Run GET test (using same prefix so it finds the objects we just uploaded)
echo "Running GET test (5s)..."
warp get \
  --host s3.us-east-2.amazonaws.com \
  --access-key "$S3_ACCESS_KEY" \
  --secret-key "$S3_SECRET_KEY" \
  --bucket "$S3_BUCKET" \
  --region "$S3_REGION" \
  --duration 5s \
  --obj.size 1MiB \
  --concurrent 8 \
  --prefix warp-bench/focused \
  --list-existing \
  --autoterm \
  --json \
  > "$RESULTS_DIR/get.json"

echo "✓ GET completed"
echo ""

# Extract GET metrics
GET_THROUGHPUT=$(jq -r '.total.throughput.bytes_per_sec // 0' "$RESULTS_DIR/get.json")
GET_OBJECTS=$(jq -r '.total.total_objects // 0' "$RESULTS_DIR/get.json")
GET_ERRORS=$(jq -r '.total.total_errors // 0' "$RESULTS_DIR/get.json")

echo "GET Results:"
echo "  Objects: $GET_OBJECTS"
echo "  Throughput: $(echo "scale=2; $GET_THROUGHPUT / 1024 / 1024" | bc) MB/s"
echo "  Errors: $GET_ERRORS"
echo ""

# Run LIST test
echo "Running LIST test (5s)..."
warp list \
  --host s3.us-east-2.amazonaws.com \
  --access-key "$S3_ACCESS_KEY" \
  --secret-key "$S3_SECRET_KEY" \
  --bucket "$S3_BUCKET" \
  --region "$S3_REGION" \
  --duration 5s \
  --concurrent 8 \
  --prefix warp-bench/focused \
  --autoterm \
  --json \
  > "$RESULTS_DIR/list.json"

echo "✓ LIST completed"
echo ""

# Extract LIST metrics
LIST_OPS=$(jq -r '.total.throughput.ops_per_sec // 0' "$RESULTS_DIR/list.json")
LIST_ERRORS=$(jq -r '.total.total_errors // 0' "$RESULTS_DIR/list.json")

echo "LIST Results:"
echo "  Ops/sec: $LIST_OPS"
echo "  Errors: $LIST_ERRORS"
echo ""

echo "=========================================="
echo "All tests completed successfully!"
echo "Results stored in: $RESULTS_DIR"
echo "=========================================="
