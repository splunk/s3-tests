#!/usr/bin/env python3
"""
Tests for the perf-tests parser and report pipeline (no S3 required).

Run from perf-tests/:
  python3 test_parser_and_report.py
  pytest test_parser_and_report.py -v   # if pytest installed
"""

import json
import sys
import tempfile
from pathlib import Path

# Allow running from repo root or perf-tests/
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from reparse_warp_raw import extract_json_from_raw, parse_warp_v2, parse_raw_filename


# Minimal warp v2 JSON (one GET run) with leading junk like real warp output
WARP_RAW_WITH_LEADING_JUNK = r"""
Throughput 48482205.0MiB/s within 7.500000% for 7s. Assuming stability. Terminating benchmark.

{
  "v": 2,
  "total": {
    "total_requests": 100,
    "total_objects": 100,
    "total_errors": 0,
    "total_bytes": 104857600,
    "throughput": {
      "measure_duration_millis": 5000,
      "bytes": 104857600,
      "objects": 100,
      "ops": 100
    },
    "requests_by_client": {
      "client1": [
        {
          "single_sized_requests": {
            "first_byte": {
              "average_millis": 20.5,
              "median_millis": 19.0,
              "p90_millis": 24.0,
              "p99_millis": 26.0
            }
          }
        }
      ]
    }
  },
  "by_op_type": {
    "GET": {
      "throughput": { "measure_duration_millis": 5000, "bytes": 104857600, "ops": 100 },
      "requests_by_client": {}
    }
  }
}
"""


def test_extract_json_strips_leading_junk():
    data = extract_json_from_raw(WARP_RAW_WITH_LEADING_JUNK)
    assert data is not None
    assert isinstance(data, dict)
    assert "total" in data
    assert data.get("total", {}).get("total_requests") == 100


def test_parse_warp_v2_extracts_metrics():
    data = extract_json_from_raw(WARP_RAW_WITH_LEADING_JUNK)
    assert data is not None
    parsed = parse_warp_v2(data, "get")
    assert parsed["throughput_mbps"] > 0
    assert parsed["errors"] == 0
    assert parsed["error_rate"] == 0
    assert parsed["total_operations"] == 100
    assert parsed["p99_latency_ms"] == 26.0
    assert parsed["avg_latency_ms"] == 20.5


def test_parse_raw_filename():
    assert parse_raw_filename("get_1MiB_c1_i1.json") == {
        "operation": "get",
        "size": "1MiB",
        "concurrency": 1,
        "iteration": 1,
    }
    assert parse_raw_filename("mixed_750MiB_c128_i3.json") == {
        "operation": "mixed",
        "size": "750MiB",
        "concurrency": 128,
        "iteration": 3,
    }
    assert parse_raw_filename("not-a-match.json") is None


def test_report_load_data_and_aggregate():
    """Ensure report.py can load summary JSON and aggregate (error rows filtered)."""
    try:
        import pandas as pd
    except ImportError:
        print("SKIP report test (pandas not installed)", file=sys.stderr)
        return
    # Import after path is set
    report = __import__("report", fromlist=["load_data", "aggregate_iterations"])
    load_data = report.load_data
    aggregate_iterations = report.aggregate_iterations

    # Valid rows + one error row (should be filtered out)
    summary = [
        {
            "target": "aws",
            "operation": "get",
            "object_size": "1MiB",
            "concurrency": 8,
            "iteration": 1,
            "throughput_mbps": 40.0,
            "ops_per_sec": 40.0,
            "avg_latency_ms": 20.0,
            "p50_latency_ms": 19.0,
            "p90_latency_ms": 24.0,
            "p99_latency_ms": 26.0,
            "total_operations": 200,
            "errors": 0,
            "error_rate": 0,
        },
        {
            "target": "other",
            "operation": "get",
            "object_size": "1MiB",
            "concurrency": 8,
            "iteration": 1,
            "throughput_mbps": 0,
            "ops_per_sec": 0,
            "errors": 0,
            "error_rate": 1.0,
            "error": "invalid_raw_output",
        },
    ]
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(summary, f)
        path = Path(f.name)
    try:
        df = load_data(path)
        assert len(df) == 1  # error row filtered
        assert df.iloc[0]["throughput_mbps"] == 40.0
        agg = aggregate_iterations(df)
        assert len(agg) == 1
    finally:
        path.unlink(missing_ok=True)


def run_all():
    tests = [
        test_extract_json_strips_leading_junk,
        test_parse_warp_v2_extracts_metrics,
        test_parse_raw_filename,
        test_report_load_data_and_aggregate,
    ]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"PASS {t.__name__}")
        except Exception as e:
            print(f"FAIL {t.__name__}: {e}")
            failed += 1
    return failed


if __name__ == "__main__":
    sys.exit(run_all())
