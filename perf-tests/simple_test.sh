#!/usr/bin/env bash
# Simple warp test to verify it works
set -euo pipefail

cd "$(dirname "$0")"
. targets/aws.env

echo "Testing warp PUT operation..."
warp put \
  --host s3.us-east-2.amazonaws.com \
  --access-key "$S3_ACCESS_KEY" \
  --secret-key "$S3_SECRET_KEY" \
  --bucket "$S3_BUCKET" \
  --region "$S3_REGION" \
  --duration 10s \
  --obj.size 1MiB \
  --concurrent 8 \
  --autoterm \
  --json > /tmp/simple_put_test.json

echo "✓ PUT test completed"
echo "Results saved to: /tmp/simple_put_test.json"
echo ""
echo "Throughput:"
cat /tmp/simple_put_test.json | jq -r '.total.throughput | "  Bytes/sec: \(.bytes)\n  Objects/sec: \(.objects)\n  Ops: \(.ops)"'
echo ""
echo "Summary:"
cat /tmp/simple_put_test.json | jq -r '.total | "  Total objects: \(.total_objects)\n  Total bytes: \(.total_bytes)\n  Errors: \(.total_errors)"'
