#!/usr/bin/env python3
"""
Re-parse raw warp benchmark output (raw/*.json) and rewrite summary.json for a run directory.
Use this to fix 'invalid_raw_output' entries when raw files contain leading non-JSON text
or warp v2 format that the original parser did not handle.

Usage:
  python3 reparse_warp_raw.py <run_dir> [<run_dir> ...]
  python3 reparse_warp_raw.py "/path/to/results/other/20260208-020124"
  python3 reparse_warp_raw.py "/path/to/results/other/20260208-020124" "/path/to/results/aws/20260206-214236"

Each run_dir must contain a raw/ subdir with *_c*_i*.json files. summary.json will be overwritten.
Target name is inferred from the parent of run_dir (e.g. .../other/20260208-... -> target=other).
"""

import json
import re
import sys
from pathlib import Path


def extract_json_from_raw(content: str):
    """Strip leading non-JSON and return parsed JSON."""
    start = content.find('{')
    if start == -1:
        return None
    json_str = content[start:]
    try:
        return json.loads(json_str)
    except json.JSONDecodeError:
        pass
    depth = 0
    end = -1
    for i, c in enumerate(json_str):
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                end = i
    if end >= 0:
        try:
            return json.loads(json_str[: end + 1])
        except json.JSONDecodeError:
            pass
    return None


def parse_warp_v2(data: dict, operation: str) -> dict:
    """Extract summary metrics from warp v2 JSON."""
    total = data.get('total') or {}
    by_op = data.get('by_op_type') or {}
    op_block = by_op.get(operation.upper()) if isinstance(by_op, dict) else {}
    if not op_block:
        op_block = total
    thr = total.get('throughput') or op_block.get('throughput') or {}
    duration_millis = thr.get('measure_duration_millis') or 0
    duration_sec = duration_millis / 1000.0 if duration_millis else 0
    bytes_val = float(thr.get('bytes') or total.get('total_bytes') or 0)
    total_requests = int(total.get('total_requests') or total.get('total_objects') or 0)
    total_errors = int(total.get('total_errors') or 0)
    ops_val = thr.get('ops') or thr.get('objects')
    if ops_val is None and total_requests and duration_sec:
        ops_val = total_requests
    ops_val = float(ops_val or 0)
    throughput_mbps = (bytes_val / (1024.0 * 1024.0)) / duration_sec if duration_sec else 0
    ops_per_sec = ops_val / duration_sec if duration_sec else 0
    error_rate = (total_errors / total_requests) if total_requests else 0
    avg_ms = p50_ms = p90_ms = p99_ms = 0
    req_by_client = op_block.get('requests_by_client') or total.get('requests_by_client') or {}
    for _client_name, segments in (req_by_client.items() if isinstance(req_by_client, dict) else []):
        for seg in segments if isinstance(segments, list) else [segments]:
            s = seg.get('single_sized_requests') or {}
            fb = s.get('first_byte') or {}
            if fb:
                avg_ms = float(fb.get('average_millis') or 0)
                p50_ms = float(fb.get('median_millis') or 0)
                p90_ms = float(fb.get('p90_millis') or 0)
                p99_ms = float(fb.get('p99_millis') or 0)
                break
            dur_avg = s.get('dur_avg_millis')
            if dur_avg is not None:
                avg_ms = float(dur_avg)
                p99_ms = float(s.get('dur_99_millis') or 0)
                p90_ms = float(s.get('dur_90_millis') or 0)
                p50_ms = float(s.get('dur_median_millis') or avg_ms)
                break
        break
    return {
        'throughput_mbps': throughput_mbps,
        'ops_per_sec': ops_per_sec,
        'avg_latency_ms': avg_ms,
        'p50_latency_ms': p50_ms,
        'p90_latency_ms': p90_ms,
        'p99_latency_ms': p99_ms,
        'total_operations': total_requests,
        'errors': total_errors,
        'error_rate': error_rate,
    }


# Filename pattern: {operation}_{size}_c{concurrency}_i{iteration}.json
FILENAME_RE = re.compile(r'^([a-zA-Z]+)_(.+)_c(\d+)_i(\d+)\.json$')


def parse_raw_filename(name: str):
    m = FILENAME_RE.match(name)
    if not m:
        return None
    return {'operation': m.group(1).lower(), 'size': m.group(2), 'concurrency': int(m.group(3)), 'iteration': int(m.group(4))}


def reparse_run_dir(run_dir: Path, target: str) -> list:
    raw_dir = run_dir / 'raw'
    if not raw_dir.is_dir():
        print(f"Warning: no raw/ in {run_dir}", file=sys.stderr)
        return []
    entries = []
    for path in sorted(raw_dir.glob('*.json')):
        info = parse_raw_filename(path.name)
        if not info:
            continue
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
        data = extract_json_from_raw(content)
        if not data:
            print(f"  Skip (no JSON): {path.name}", file=sys.stderr)
            continue
        entry = {
            'target': target,
            'operation': info['operation'],
            'object_size': info['size'],
            'concurrency': info['concurrency'],
            'iteration': info['iteration'],
            'throughput_mbps': 0,
            'ops_per_sec': 0,
            'avg_latency_ms': 0,
            'p50_latency_ms': 0,
            'p90_latency_ms': 0,
            'p99_latency_ms': 0,
            'total_operations': 0,
            'errors': 0,
            'error_rate': 0,
        }
        if isinstance(data, dict) and data.get('total') is not None:
            parsed = parse_warp_v2(data, info['operation'])
            entry.update(parsed)
        else:
            r0 = data[0] if isinstance(data, list) and len(data) > 0 else data
            if not isinstance(r0, dict):
                continue
            entry['throughput_mbps'] = float(r0.get('throughput_mb', 0) or 0)
            entry['ops_per_sec'] = float(r0.get('ops_per_sec', 0) or 0)
            entry['avg_latency_ms'] = float(r0.get('latency_avg_ms', 0) or 0)
            entry['p50_latency_ms'] = float(r0.get('latency_p50_ms', 0) or 0)
            entry['p90_latency_ms'] = float(r0.get('latency_p90_ms', 0) or 0)
            entry['p99_latency_ms'] = float(r0.get('latency_p99_ms', 0) or 0)
            entry['total_operations'] = int(r0.get('operations', 0) or 0)
            entry['errors'] = int(r0.get('errors', 0) or 0)
            entry['error_rate'] = float(r0.get('error_rate', 0) or 0)
        entries.append(entry)
    return entries


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    for run_dir_arg in sys.argv[1:]:
        run_dir = Path(run_dir_arg).resolve()
        if not run_dir.is_dir():
            print(f"Error: not a directory: {run_dir}", file=sys.stderr)
            sys.exit(2)
        target = run_dir.parent.name
        entries = reparse_run_dir(run_dir, target)
        summary_file = run_dir / 'summary.json'
        if not entries:
            print(f"No valid entries for {run_dir} (all raw files empty or non-JSON). Writing empty summary.", file=sys.stderr)
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(entries, f, indent=2)
        print(f"Wrote {len(entries)} entries to {summary_file}")


if __name__ == '__main__':
    main()
