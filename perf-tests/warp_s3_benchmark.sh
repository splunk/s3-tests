#!/usr/bin/env bash
#
# warp_s3_benchmark.sh - Comprehensive S3 Benchmarking with MinIO WARP
#
# Usage:
#   ./warp_s3_benchmark.sh --target aws
#   ./warp_s3_benchmark.sh --target other
#   ./warp_s3_benchmark.sh --target aws --target other --compare --report
#   ./warp_s3_benchmark.sh --report --use-latest
#

set -euo pipefail

# ============================================================================
# Configuration & Defaults
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use the perf-tests local targets directory (do not read repo-root targets)
TARGETS_DIR="${SCRIPT_DIR}/targets"

# Print which targets dir is used
echo "[INFO] Using targets directory: ${TARGETS_DIR}" >&2
RESULTS_DIR="${SCRIPT_DIR}/results"

# Benchmark defaults
DEFAULT_DURATION="5m"
DEFAULT_WARMUP="30s"
DEFAULT_SIZES="4KiB,64KiB,1MiB,16MiB,128MiB,750MiB"
DEFAULT_CONCURRENCY="1,8,32,128"
DEFAULT_ITERATIONS=3
DEFAULT_OBJECTS=1000

# Runtime config
TARGETS=()
DURATION="${DEFAULT_DURATION}"
WARMUP="${DEFAULT_WARMUP}"
SIZES="${DEFAULT_SIZES}"
CONCURRENCY="${DEFAULT_CONCURRENCY}"
ITERATIONS="${DEFAULT_ITERATIONS}"
OBJECTS="${DEFAULT_OBJECTS}"
DO_COMPARE=false
DO_REPORT=false
USE_LATEST=false
SKIP_CLEANUP=false
VERBOSE=false
HEARTBEAT_INTERVAL=30

# ============================================================================
# Utility Functions
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

warn() {
    echo "[WARN] $*" >&2
}

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Convert duration strings like "3m", "30s", "1h30m" into seconds.
duration_to_seconds() {
    local input="$1"
    local total=0
    # Find all occurrences like 1h, 30m, 45s
    while [[ -n "$input" ]]; do
        if [[ "$input" =~ ^([0-9]+)h(.*)$ ]]; then
            total=$((total + ${BASH_REMATCH[1]} * 3600))
            input="${BASH_REMATCH[2]}"
        elif [[ "$input" =~ ^([0-9]+)m(.*)$ ]]; then
            total=$((total + ${BASH_REMATCH[1]} * 60))
            input="${BASH_REMATCH[2]}"
        elif [[ "$input" =~ ^([0-9]+)s(.*)$ ]]; then
            total=$((total + ${BASH_REMATCH[1]}))
            input="${BASH_REMATCH[2]}"
        elif [[ "$input" =~ ^([0-9]+)(.*)$ ]]; then
            # Plain number (seconds)
            total=$((total + ${BASH_REMATCH[1]}))
            input="${BASH_REMATCH[2]}"
        else
            # Unknown format, break
            break
        fi
    done
    echo "$total"
}

# Format seconds to human readable form
human_readable_seconds() {
    local secs=$1
    local days=$((secs/86400))
    local hours=$(( (secs%86400)/3600 ))
    local mins=$(( (secs%3600)/60 ))
    local s=$((secs%60))
    if (( days > 0 )); then
        printf "%dd %02dh %02dm %02ds" "$days" "$hours" "$mins" "$s"
    elif (( hours > 0 )); then
        printf "%02dh %02dm %02ds" "$hours" "$mins" "$s"
    elif (( mins > 0 )); then
        printf "%02dm %02ds" "$mins" "$s"
    else
        printf "%02ds" "$s"
    fi
}

# Run a command and print periodic heartbeats so the user can see progress.
run_with_heartbeat() {
    local raw_output="$1"
    shift
    # Start the command, redirect both stdout and stderr to the raw_output file
    # The command should run in background so we can print heartbeats
    ("$@" >"$raw_output" 2>&1) &
    local cmd_pid=$!
    local start_ts=$(date +%s)
    log "Started pid=$cmd_pid"

    # Determine an expected timeout by parsing --duration from the command args (fallback: global DURATION or 10m)
    local expected_secs=0
    for a in "$@"; do
        if [[ "$a" =~ ^--duration= ]]; then
            local dur_val="${a#--duration=}"
            expected_secs=$(duration_to_seconds "$dur_val")
            break
        fi
    done
    if [[ $expected_secs -eq 0 ]]; then
        # fallback to script-level DURATION if set, else default to 600s
        expected_secs=$(duration_to_seconds "${DURATION:-10m}")
    fi
    # Add a buffer to allow for warmup/teardown time
    local timeout_buffer=30
    local timeout_secs=$((expected_secs + timeout_buffer))

    # Print heartbeat every $HEARTBEAT_INTERVAL seconds while process is running
    local interval=${HEARTBEAT_INTERVAL}
    while kill -0 "$cmd_pid" 2>/dev/null; do
        sleep "$interval"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            local now=$(date +%s)
            local elapsed=$((now - start_ts))
            log "pid=$cmd_pid still running (elapsed: $(human_readable_seconds "$elapsed")) - output: $raw_output"
            # If the process has exceeded expected duration + buffer, terminate it to avoid hanging
            if [[ $elapsed -gt $timeout_secs ]]; then
                warn "pid=$cmd_pid exceeded expected duration (${timeout_secs}s). Terminating to avoid hang."
                kill "$cmd_pid" 2>/dev/null || true
                # give it a moment to exit gracefully
                sleep 5
                if kill -0 "$cmd_pid" 2>/dev/null; then
                    warn "pid=$cmd_pid did not exit after TERM; sending KILL"
                    kill -9 "$cmd_pid" 2>/dev/null || true
                fi
                # Wait for any remaining child reaping
                wait "$cmd_pid" 2>/dev/null || true
                return 124
            fi
        fi
    done

    # Wait for the command to exit to capture exit status
    wait "$cmd_pid" || return $?
    return 0
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --target NAME           Target to benchmark (aws, other, etc.)
                         Can be specified multiple times
  --duration DURATION     Test duration (default: ${DEFAULT_DURATION})
  --warmup WARMUP        Warmup duration (default: ${DEFAULT_WARMUP})
  --sizes SIZES          Comma-separated sizes (default: ${DEFAULT_SIZES})
  --concurrency CONC     Comma-separated concurrency levels (default: ${DEFAULT_CONCURRENCY})
  --iterations N         Number of iterations per test (default: ${DEFAULT_ITERATIONS})
  --objects N            Number of objects per test (default: ${DEFAULT_OBJECTS})
  --compare              Generate comparison after running targets
  --report               Generate final HTML report
  --use-latest           Use latest results for comparison/report
  --skip-cleanup         Don't clean up test objects
  --verbose              Enable verbose logging
  -h, --help             Show this help

Examples:
  # Run AWS baseline
  $0 --target aws

  # Run comparison target
  $0 --target other

  # Run both and generate report
  $0 --target aws --target other --compare --report

  # Regenerate report from latest data
  $0 --report --use-latest

EOF
    exit 0
}

# ============================================================================
# Preflight Checks
# ============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check for warp
    if ! command -v warp &> /dev/null; then
        error "warp is not installed. Install from: https://github.com/minio/warp"
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    # Check for python3
    if ! command -v python3 &> /dev/null; then
        error "python3 is not installed"
    fi
    
    # Check for required Python modules (optional for graphing)
    if ! python3 -c "import matplotlib, pandas, jinja2" 2>/dev/null; then
        warn "Python plotting dependencies missing (matplotlib, pandas, jinja2, seaborn)"
        warn "Graphs will be skipped. To enable, install in a virtualenv:"
        warn "  python3 -m venv .venv && source .venv/bin/activate"
        warn "  pip install matplotlib pandas jinja2 seaborn"
    fi
    
    # Print versions
    log "Tool versions:"
    warp --version 2>&1 | head -1 || echo "  warp: unknown"
    jq --version || echo "  jq: unknown"
    python3 --version || echo "  python3: unknown"
    
    # Print system info
    log "System info:"
    uname -a
    
    log "Prerequisites check passed"
}

check_target_config() {
    local target="$1"
    local config_file="${TARGETS_DIR}/${target}.env"
    
    if [[ ! -f "$config_file" ]]; then
        error "Target configuration not found: $config_file"
    fi
    
    # Source and validate
    set -a
    source "$config_file"
    set +a
    
    # Required variables
    local required_vars=(
        "S3_ENDPOINT"
        "S3_ACCESS_KEY"
        "S3_SECRET_KEY"
        "S3_BUCKET"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Missing required variable $var in $config_file"
        fi
    done

    # Detect common placeholder values that indicate the user hasn't configured credentials
    if [[ "${S3_ACCESS_KEY:-}" == "YOUR_*" || "${S3_ACCESS_KEY:-}" =~ YOUR_AWS_ACCESS_KEY_ID || "${S3_SECRET_KEY:-}" =~ YOUR_AWS_SECRET_ACCESS_KEY ]]; then
        error "S3 access key/secret in $config_file look like placeholders. Please set real credentials or export S3_ACCESS_KEY/S3_SECRET_KEY in your environment."
    fi

    if [[ "${S3_ACCESS_KEY:-}" == "" || "${S3_SECRET_KEY:-}" == "" ]]; then
        error "S3_ACCESS_KEY or S3_SECRET_KEY is empty in $config_file. Please provide valid credentials."
    fi
    
    log "Target '$target' configuration validated"
}

# ============================================================================
# Benchmark Execution
# ============================================================================

run_benchmark_suite() {
    local target="$1"
    local timestamp="$(date '+%Y%m%d-%H%M%S')"
    local target_dir="${RESULTS_DIR}/${target}/${timestamp}"
    local raw_dir="${target_dir}/raw"
    local summary_file="${target_dir}/summary.json"
    
    log "Starting benchmark suite for target: $target"
    log "Results will be stored in: $target_dir"
    
    # Create directories
    mkdir -p "$raw_dir"
    
    # Load target config
    set -a
    source "${TARGETS_DIR}/${target}.env"
    set +a
    # Print loaded config (mask secrets) to help debug access issues
    {
        masked_access=$(printf '%s' "${S3_ACCESS_KEY:-}" | sed -E 's/(.{4}).*(.{4})/\1****\2/')
        masked_secret=$(printf '%s' "${S3_SECRET_KEY:-}" | sed -E 's/(.{4}).*(.{4})/\1****\2/')
        echo "[DEBUG] Loaded target config:" >&2
        echo "[DEBUG]   S3_ENDPOINT=${S3_ENDPOINT:-}" >&2
        echo "[DEBUG]   S3_BUCKET=${S3_BUCKET:-}" >&2
        echo "[DEBUG]   S3_REGION=${S3_REGION:-}" >&2
        echo "[DEBUG]   S3_TLS=${S3_TLS:-}" >&2
        echo "[DEBUG]   S3_PATH_STYLE=${S3_PATH_STYLE:-}" >&2
        echo "[DEBUG]   S3_ACCESS_KEY=${masked_access:-}" >&2
        echo "[DEBUG]   S3_SECRET_KEY=${masked_secret:-}" >&2
    }

    # Normalize S3_ENDPOINT: ensure scheme is present (warp expects full URL)
    if [[ -n "${S3_ENDPOINT:-}" && ! "${S3_ENDPOINT}" =~ ^https?:// ]]; then
        S3_ENDPOINT="https://${S3_ENDPOINT}"
        echo "[DEBUG] Normalized S3_ENDPOINT to ${S3_ENDPOINT}" >&2
    fi

    # Normalize S3_TLS values to true/false (use portable lowercase conversion)
    if [[ -n "${S3_TLS:-}" ]]; then
        tls_lc="$(printf '%s' "${S3_TLS}" | tr '[:upper:]' '[:lower:]')"
        case "$tls_lc" in
            yes|true|1)
                S3_TLS="true" ;;
            no|false|0)
                S3_TLS="false" ;;
            *)
                S3_TLS="true" ;;
        esac
    else
        S3_TLS="true"
    fi

    # Validate bucket access
    validate_bucket_access "$target"
    
    # Initialize summary
    echo "[]" > "$summary_file"
    
    # Parse sizes and concurrency
    IFS=',' read -ra SIZE_ARRAY <<< "$SIZES"
    IFS=',' read -ra CONC_ARRAY <<< "$CONCURRENCY"

    # Trim whitespace from parsed tokens (allow inputs like "4KiB, 64KiB")
    for i in "${!SIZE_ARRAY[@]}"; do
        # remove leading/trailing spaces
        SIZE_ARRAY[$i]="$(printf '%s' "${SIZE_ARRAY[$i]}" | sed -E 's/^\s+|\s+$//g')"
    done
    for i in "${!CONC_ARRAY[@]}"; do
        CONC_ARRAY[$i]="$(printf '%s' "${CONC_ARRAY[$i]}" | sed -E 's/^\s+|\s+$//g')"
    done

    # Define the operations and export a planned test suite file (human + JSON)
    # so it's easy to inspect before running
    local operations=(
        "put"
        "get"
        "delete"
        "list"
        "mixed"
    )
    mkdir -p "$target_dir"
    local planned_txt="${target_dir}/planned_tests.txt"
    local planned_json="${target_dir}/planned_tests.json"
    : > "$planned_txt"
    : > "$planned_json"
    # Build JSON list using python to avoid shell quoting pitfalls
    # Pass the arrays as arguments to the embedded python script (safe and portable)
    python3 - "$planned_json" "${operations[*]}" "${SIZE_ARRAY[*]}" "${CONC_ARRAY[*]}" "$ITERATIONS" <<'PY' > /dev/null 2>&1
import sys, json
output_path = sys.argv[1]
ops = sys.argv[2].split()
sizes = sys.argv[3].split()
concs = sys.argv[4].split()
iters = int(sys.argv[5])
planned = []
for op in ops:
    for s in sizes:
        for c in concs:
            for i in range(1, iters+1):
                planned.append({"operation": op, "size": s, "concurrency": int(c), "iteration": i})
open(output_path, 'w', encoding='utf-8').write(json.dumps(planned, indent=2))
PY

    # Also write a human-readable list
    for op in "${operations[@]}"; do
        for s in "${SIZE_ARRAY[@]}"; do
            for c in "${CONC_ARRAY[@]}"; do
                for it in $(seq 1 $ITERATIONS); do
                    echo "$op size=$s concurrency=$c iteration=$it" >> "$planned_txt"
                done
            done
        done
    done

    log "Planned tests written: $planned_txt and $planned_json"
    
    # Benchmark operations (operations defined above)
    local total_tests=$((${#operations[@]} * ${#SIZE_ARRAY[@]} * ${#CONC_ARRAY[@]} * $ITERATIONS))
    local current_test=0
    
    # Estimate total run time: convert durations to seconds
    local duration_secs=$(duration_to_seconds "$DURATION")
    local warmup_secs=$(duration_to_seconds "$WARMUP")

    # Heuristic: per-operation overhead in seconds (setup/teardown/parsing)
    # put/get: higher overhead due to object creation; list/delete: lower
    estimate_overhead() {
        local op="$1"
        local conc="$2"
        local base=10
        case "$op" in
            put|get)
                base=20
                ;;
            mixed)
                base=25
                ;;
            list|delete)
                base=8
                ;;
            *)
                base=12
                ;;
        esac
        # Additional overhead for high concurrency
        if (( conc >= 64 )); then
            base=$((base + 10))
        elif (( conc >= 16 )); then
            base=$((base + 4))
        fi
        echo "$base"
    }

    # Compute an initial estimate using the first operation heuristic (conservative)
    local sample_overhead=15
    local est_one_test_secs=$((duration_secs + warmup_secs + sample_overhead))
    local est_total_secs=$((est_one_test_secs * total_tests))

    log "Running $total_tests tests... Estimated total time (initial): $(human_readable_seconds "$est_total_secs")"

    # Track elapsed time to compute dynamic ETA
    local suite_start_ts=$(date +%s)
    local completed_tests=0
    local cumulative_elapsed=0
    
    # Track which size/concurrency combos have been prepared with objects (simple string list)
    local prepared_prefixes=""
    
    for operation in "${operations[@]}"; do
        for size in "${SIZE_ARRAY[@]}"; do
            for concurrency in "${CONC_ARRAY[@]}"; do
                # NOTE: We no longer pre-populate objects because:
                # - PUT uses --noclear to keep objects after completion
                # - GET/DELETE use --list-existing to use objects from previous PUT tests
                # This approach is more efficient and matches how warp is designed to work
                
                for iteration in $(seq 1 $ITERATIONS); do
                    current_test=$((current_test + 1))
                    log "Test $current_test/$total_tests: $operation size=$size concurrency=$concurrency iteration=$iteration"
                    log "Starting test: $operation size=$size concurrency=$concurrency iteration=$iteration"
                    local test_start_ts=$(date +%s)

                    run_single_benchmark \
                        "$target" \
                        "$operation" \
                        "$size" \
                        "$concurrency" \
                        "$iteration" \
                        "$raw_dir" \
                        "$summary_file"

                    local test_end_ts=$(date +%s)
                    local test_elapsed=$((test_end_ts - test_start_ts))
                    log "Finished test: $operation size=$size concurrency=$concurrency iteration=$iteration (elapsed: $(human_readable_seconds "$test_elapsed"))"

                    # Update dynamic ETA
                    completed_tests=$((completed_tests + 1))
                    cumulative_elapsed=$((cumulative_elapsed + test_elapsed))
                    local avg_per_test=$((cumulative_elapsed / completed_tests))
                    local remaining_tests=$((total_tests - completed_tests))
                    local est_remaining_secs=$((avg_per_test * remaining_tests))
                    log "Progress: $completed_tests/$total_tests tests completed. Estimated remaining time: $(human_readable_seconds "$est_remaining_secs")"
                done
            done
        done
    done
    
    # Save metadata
    save_metadata "$target" "$target_dir"
    
    log "Benchmark suite completed for $target"
    log "Summary: $summary_file"
    
    # Return the results directory for later use
    echo "$target_dir"
}

prepare_test_objects() {
    local target="$1"
    local size="$2"
    local concurrency="$3"
    local raw_dir="$4"
    
    local prefix="warp-bench/${target}/${size}_c${concurrency}"
    local prep_output="${raw_dir}/prep_${size}_c${concurrency}.json"
    
    # Derive warp host
    local _ep_no_scheme_prep="${S3_ENDPOINT#http://}"
    _ep_no_scheme_prep="${_ep_no_scheme_prep#https://}"
    local WARP_HOST_PREP="${_ep_no_scheme_prep%%/*}"
    
    local prep_cmd=(
        warp put
        --host "${WARP_HOST_PREP}"
        --access-key "${S3_ACCESS_KEY}"
        --secret-key "${S3_SECRET_KEY}"
        --bucket "${S3_BUCKET}"
        --obj.size "$size"
        --prefix "$prefix"
        --concurrent "$concurrency"
        --duration 30s
        --autoterm
        --quiet
    )
    
    if [[ -n "${S3_REGION:-}" ]]; then
        prep_cmd+=(--region "$S3_REGION")
    fi
    
    if [[ "${S3_TLS:-true}" == "false" ]]; then
        prep_cmd+=(--insecure)
    fi
    
    if [[ "${S3_PATH_STYLE:-false}" == "true" ]]; then
        prep_cmd+=(--host-style=path)
    fi
    
    log "Uploading $OBJECTS test objects (size=$size, prefix=$prefix)..."
    if "${prep_cmd[@]}" >"$prep_output" 2>&1; then
        log "Test objects prepared successfully"
    else
        warn "Failed to prepare test objects (see $prep_output). Read operations may fail."
    fi
}

run_single_benchmark() {
    local target="$1"
    local operation="$2"
    local size="$3"
    local concurrency="$4"
    local iteration="$5"
    local raw_dir="$6"
    local summary_file="$7"
    
    local test_name="${operation}_${size}_c${concurrency}_i${iteration}"
    local raw_output="${raw_dir}/${test_name}.json"
    
    # Use a shared prefix for operations that need existing objects (get, delete, list, stat, mixed)
    # This ensures GET/DELETE/LIST can find objects created by earlier operations
    local prefix="warp-bench/${target}/${size}_c${concurrency}"
    
    # Build warp command
    # Derive warp host for this run (strip scheme/path)
    local _ep_no_scheme_run="${S3_ENDPOINT#http://}"
    _ep_no_scheme_run="${_ep_no_scheme_run#https://}"
    local WARP_HOST_RUN="${_ep_no_scheme_run%%/*}"
    verbose "Derived warp host for run: ${WARP_HOST_RUN}"

    local warp_cmd=(
        warp "$operation"
        --host "${WARP_HOST_RUN}"
        --access-key "${S3_ACCESS_KEY}"
        --secret-key "${S3_SECRET_KEY}"
        --bucket "${S3_BUCKET}"
        --duration "$DURATION"
        --concurrent "$concurrency"
        --obj.size "$size"
        --prefix "$prefix"
        --json
        --autoterm
    )
    
    # Add operation-specific flags
    # PUT: Keep objects for subsequent GET/DELETE/LIST tests
    if [[ "$operation" == "put" ]]; then
        warp_cmd+=(--noclear)
    fi
    
    # GET and DELETE: Use existing objects instead of uploading new ones
    if [[ "$operation" == "get" || "$operation" == "delete" ]]; then
        warp_cmd+=(--list-existing)
    fi
    
    # Add optional parameters
    if [[ -n "${S3_REGION:-}" ]]; then
        warp_cmd+=(--region "$S3_REGION")
    fi
    
    if [[ "${S3_TLS:-true}" == "false" ]]; then
        warp_cmd+=(--insecure)
    fi
    
    if [[ "${S3_PATH_STYLE:-false}" == "true" ]]; then
        warp_cmd+=(--host-style=path)
    fi
    
    # warp does not support a --warmup flag; run a separate warmup invocation if requested
    # (we'll run warmup before the main benchmark run to let caches/warm paths stabilize)
    
    # If a warmup is configured, run it first (discarding output) so the main run is stable
    if [[ "$WARMUP" != "0s" && "$WARMUP" != "0" ]]; then
        local warmup_output
        warmup_output=$(mktemp "${raw_dir}/${test_name}.warmup.XXXXXX")
        # Build warmup command copying warp_cmd but with duration set to WARMUP
        local warmup_cmd=()
        for arg in "${warp_cmd[@]}"; do
            warmup_cmd+=("$arg")
        done
        # Replace the --duration argument (if present) with warmup duration
        for i in "${!warmup_cmd[@]}"; do
            if [[ "${warmup_cmd[$i]}" =~ ^--duration=.+ ]]; then
                warmup_cmd[$i]="--duration=$WARMUP"
            fi
        done

        verbose "Running warmup: ${warmup_cmd[*]}"
        log "Warmup run started: ${test_name} (duration: $WARMUP)"
        # Run warmup (we don't fail the whole test if warmup fails)
        if run_with_heartbeat "$warmup_output" "${warmup_cmd[@]}"; then
            log "Warmup completed: ${test_name}"
        else
            warn "Warmup failed: ${test_name} (see $warmup_output for details)"
        fi
        rm -f "$warmup_output"
    fi

    # Run benchmark with heartbeat so progress is visible
    verbose "Running: ${warp_cmd[*]}"
    log "Test run started: $test_name (output: $raw_output)"

    if run_with_heartbeat "$raw_output" "${warp_cmd[@]}"; then
        log "Test run completed: $test_name"
    else
        warn "Benchmark failed: $test_name (see $raw_output for details)"
    fi

    # Parse and add to summary (will append an error entry if raw output is invalid)
    parse_warp_output "$target" "$operation" "$size" "$concurrency" "$iteration" "$raw_output" "$summary_file"
    
    # Cleanup objects unless --skip-cleanup
    if [[ "$SKIP_CLEANUP" == "false" ]]; then
        cleanup_test_objects "$prefix"
    fi
}

parse_warp_output() {
    local target="$1"
    local operation="$2"
    local size="$3"
    local concurrency="$4"
    local iteration="$5"
    local raw_output="$6"
    local summary_file="$7"

    # Temporarily disable exit-on-error so parsing failures don't kill the whole run
    set +e

    # Ensure summary file exists and is a JSON array
    if [[ ! -f "$summary_file" ]]; then
        echo '[]' > "$summary_file"
    fi

    # Prepare a temporary file to hold the new entry (use jq to produce valid JSON)
    local new_entry_file
    new_entry_file=$(mktemp "${summary_file}.entry.XXXXXX")

    # If raw output is valid JSON, extract metrics. Otherwise, append a structured error entry
    if jq -e . "$raw_output" >/dev/null 2>&1; then
        # Use Python to parse raw JSON and create a summary entry to avoid jq edge cases
        python3 - "$raw_output" "$target" "$operation" "$size" "$concurrency" "$iteration" "$new_entry_file" <<'PY'
import json,sys
raw_path=sys.argv[1]
target=sys.argv[2]
operation=sys.argv[3]
size=sys.argv[4]
concurrency=int(sys.argv[5])
iteration=int(sys.argv[6])
out_path=sys.argv[7]

entry={
    'target': target,
    'operation': operation,
    'object_size': size,
    'concurrency': concurrency,
    'iteration': iteration,
    'throughput_mbps': 0,
    'ops_per_sec': 0,
    'avg_latency_ms': 0,
    'p50_latency_ms': 0,
    'p90_latency_ms': 0,
    'p99_latency_ms': 0,
    'total_operations': 0,
    'errors': 0,
    'error_rate': 0
}
try:
    with open(raw_path,'r',encoding='utf-8',errors='replace') as f:
        data=json.load(f)
    # raw can be an object or list
    r0 = data[0] if isinstance(data,list) and len(data)>0 else data
    entry['throughput_mbps']=float(r0.get('throughput_mb',0) or 0)
    entry['ops_per_sec']=float(r0.get('ops_per_sec',0) or 0)
    entry['avg_latency_ms']=float(r0.get('latency_avg_ms',0) or 0)
    entry['p50_latency_ms']=float(r0.get('latency_p50_ms',0) or 0)
    entry['p90_latency_ms']=float(r0.get('latency_p90_ms',0) or 0)
    entry['p99_latency_ms']=float(r0.get('latency_p99_ms',0) or 0)
    entry['total_operations']=int(r0.get('operations',0) or 0)
    entry['errors']=int(r0.get('errors',0) or 0)
    entry['error_rate']=float(r0.get('error_rate',0) or 0)
except Exception as e:
    entry['error']='parse_error'
    entry['error_msg']=str(e)

with open(out_path,'w',encoding='utf-8') as f:
    json.dump(entry,f)

PY
    else
        # Mask credentials for safe display in the error entry
        local ak="${S3_ACCESS_KEY:-}"
        local sk="${S3_SECRET_KEY:-}"
        local ak_masked
        local sk_masked
        ak_masked=$(printf '%s' "$ak" | sed -E 's/(.{4}).*(.{4})/\1****\2/')
        sk_masked=$(printf '%s' "$sk" | sed -E 's/(.{4}).*(.{4})/\1****\2/')

        # Capture the tail of the raw output and mask any literal credentials safely using python
        local raw_tail
        raw_tail=$(tail -n 200 "$raw_output" 2>/dev/null | AK="$ak" SK="$sk" AKM="$ak_masked" SKM="$sk_masked" python3 - <<'PY'
import os,sys
ak=os.environ.get('AK','')
sk=os.environ.get('SK','')
akm=os.environ.get('AKM','')
skm=os.environ.get('SKM','')
data=sys.stdin.read()
if ak:
    data=data.replace(ak, akm)
if sk:
    data=data.replace(sk, skm)
sys.stdout.write(data)
PY
)

        # Use base64 encoding for the raw tail to avoid JSON encoding issues
        local raw_tail_b64
        raw_tail_b64=$(printf '%s' "$raw_tail" | base64 | tr -d '\n')

                # Write a safe fallback JSON entry using python to ensure valid JSON
                python3 - "$target" "$operation" "$size" "$concurrency" "$iteration" "$raw_tail_b64" "$new_entry_file" <<'PY'
import json,sys
target=sys.argv[1]
operation=sys.argv[2]
size=sys.argv[3]
concurrency=int(sys.argv[4])
iteration=int(sys.argv[5])
raw_tail_b64=sys.argv[6]
out_path=sys.argv[7]
entry={
    'target': target,
    'operation': operation,
    'object_size': size,
    'concurrency': concurrency,
    'iteration': iteration,
    'throughput_mbps': 0,
    'ops_per_sec': 0,
    'avg_latency_ms': 0,
    'total_operations': 0,
    'errors': 0,
    'error_rate': 1.0,
    'error': 'invalid_raw_output',
    'raw_tail_b64': raw_tail_b64
}
with open(out_path,'w',encoding='utf-8') as f:
        json.dump(entry,f)
PY
    fi

    # If jq/python failed to write a new entry (empty file), write a minimal fallback entry
    if [[ ! -s "$new_entry_file" ]]; then
        echo "[WARN] new entry file is empty; writing fallback entry" >&2
        printf '{"target":"%s","operation":"%s","object_size":"%s","concurrency":%s,"iteration":%s,"error":"entry_generation_failed"}' \
            "$target" "$operation" "$size" "$concurrency" "$iteration" > "$new_entry_file"
    fi

    local tmp_file="${summary_file}.tmp"
    if jq -s '.[0] + [.[1]]' "$summary_file" "$new_entry_file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$summary_file"
        verbose "Appended new summary entry for $target/$operation size=$size concurrency=$concurrency iteration=$iteration"
    else
        echo "[ERROR] Failed to append summary entry. New entry saved at: $new_entry_file" >&2
        rm -f "$tmp_file"
    fi
    # cleanup temp entry file
    rm -f "$new_entry_file"

    # Re-enable exit-on-error for the rest of the script
    set -e
}

validate_bucket_access() {
    local target="$1"

    log "Validating bucket access for $target..."

    # Try to list bucket using a quick mixed test (validates read and write)
    # Derive warp host: strip scheme and any path (warp/minio client expects host only)
    local _ep_no_scheme="${S3_ENDPOINT#http://}"
    _ep_no_scheme="${_ep_no_scheme#https://}"
    local WARP_HOST="${_ep_no_scheme%%/*}"
    echo "[DEBUG] Derived warp host: ${WARP_HOST}" >&2

    # Use a simple put operation to validate access (faster than list which needs prep)
    local test_cmd=(
        warp put
        --host "${WARP_HOST}"
        --access-key "${S3_ACCESS_KEY}"
        --secret-key "${S3_SECRET_KEY}"
        --bucket "${S3_BUCKET}"
        --obj.size 1KiB
        --duration 5s
        --concurrent 1
        --autoterm
        --prefix "warp-validation-test"
    )

    if [[ -n "${S3_REGION:-}" ]]; then
        test_cmd+=(--region "$S3_REGION")
    fi

    if [[ "${S3_TLS:-true}" == "false" ]]; then
        test_cmd+=(--insecure)
    fi

    # Capture output to a temp file so we can show the real warp error if it fails
    local tmp_out
    tmp_out=$(mktemp /tmp/warp_validate.XXXXXX)
    if "${test_cmd[@]}" >"$tmp_out" 2>&1; then
        log "Bucket access validated for $target"
        rm -f "$tmp_out"
    else
        # Mask credentials for display
        local ak="${S3_ACCESS_KEY:-}"
        local sk="${S3_SECRET_KEY:-}"
        local ak_masked
        local sk_masked
        ak_masked=$(printf '%s' "$ak" | sed -E 's/(.{4}).*(.{4})/\\1****\\2/')
        sk_masked=$(printf '%s' "$sk" | sed -E 's/(.{4}).*(.{4})/\\1****\\2/')

        echo "[ERROR] Failed to access bucket for $target. Showing warp output (masked):" >&2
        # Print the last 200 lines of output with secrets masked using a safe python heredoc
        AK="$ak" SK="$sk" AKM="$ak_masked" SKM="$sk_masked" python3 - "$tmp_out" <<'PY'
import os,sys
ak=os.environ.get('AK','')
sk=os.environ.get('SK','')
akm=os.environ.get('AKM','')
skm=os.environ.get('SKM','')
path=sys.argv[1]
with open(path,'r', encoding='utf-8', errors='replace') as f:
    data=f.read()
if ak:
    data=data.replace(ak, akm)
if sk:
    data=data.replace(sk, skm)
sys.stdout.write(data)
PY

        # Also print the command used (masked) using python-safe replacement reading stdin
        local cmd_print="${test_cmd[*]}"
        cmd_print=$(printf '%s' "$cmd_print" | AK="$ak" SK="$sk" AKM="$ak_masked" SKM="$sk_masked" python3 - <<'PY'
import os,sys
ak=os.environ.get('AK','')
sk=os.environ.get('SK','')
akm=os.environ.get('AKM','')
skm=os.environ.get('SKM','')
data=sys.stdin.read()
if ak:
    data=data.replace(ak, akm)
if sk:
    data=data.replace(sk, skm)
sys.stdout.write(data)
PY
)
        echo "[DEBUG] warp command used: $cmd_print" >&2

        rm -f "$tmp_out"
        error "Failed to access bucket for $target. Check credentials and bucket name."
    fi
}

cleanup_test_objects() {
    local prefix="$1"
    verbose "Cleaning up objects with prefix: $prefix"
    # WARP typically cleans up its own objects, but we can add explicit cleanup if needed
}

save_metadata() {
    local target="$1"
    local target_dir="$2"
    
    local metadata_file="${target_dir}/metadata.json"
    
    jq -n \
        --arg target "$target" \
        --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --arg hostname "$(hostname)" \
        --arg os "$(uname -s)" \
        --arg kernel "$(uname -r)" \
        --arg warp_version "$(warp --version 2>&1 | head -1)" \
        --arg duration "$DURATION" \
        --arg warmup "$WARMUP" \
        --arg sizes "$SIZES" \
        --arg concurrency "$CONCURRENCY" \
        --argjson iterations "$ITERATIONS" \
        --arg endpoint "${S3_ENDPOINT}" \
        --arg bucket "${S3_BUCKET}" \
        --arg region "${S3_REGION:-none}" \
        '{
            target: $target,
            timestamp: $timestamp,
            environment: {
                hostname: $hostname,
                os: $os,
                kernel: $kernel,
                warp_version: $warp_version
            },
            configuration: {
                duration: $duration,
                warmup: $warmup,
                sizes: $sizes,
                concurrency: $concurrency,
                iterations: $iterations
            },
            target_config: {
                endpoint: $endpoint,
                bucket: $bucket,
                region: $region
            }
        }' > "$metadata_file"
    
    log "Metadata saved: $metadata_file"
}

# ============================================================================
# Comparison & Analysis
# ============================================================================

generate_comparison() {
    log "Generating comparison report..."
    
    # Find latest results for each target
    local target_dirs=()
    for target in "${TARGETS[@]}"; do
        local latest_dir=$(find "$RESULTS_DIR/$target" -maxdepth 1 -type d | sort -r | head -1)
        if [[ -z "$latest_dir" ]]; then
            error "No results found for target: $target"
        fi
        target_dirs+=("$latest_dir")
        log "Using results from: $latest_dir"
    done
    
    # Generate comparison
    local timestamp="$(date '+%Y%m%d-%H%M%S')"
    local compare_dir="${RESULTS_DIR}/compare_${timestamp}"
    mkdir -p "$compare_dir"
    
    # Merge summaries
    local merged_summary="${compare_dir}/merged_summary.json"
    jq -s 'add' "${target_dirs[@]/%//summary.json}" > "$merged_summary"
    
    log "Comparison data generated: $merged_summary"
    echo "$compare_dir"
}

# ============================================================================
# Reporting
# ============================================================================

generate_report() {
    local compare_dir="$1"
    
    log "Generating graphs and HTML report..."
    
    local charts_dir="${compare_dir}/charts"
    mkdir -p "$charts_dir"
    
    # Call Python script to generate graphs and report
    python3 "${SCRIPT_DIR}/report.py" \
        --input "${compare_dir}/merged_summary.json" \
        --output "${compare_dir}/final_report.html" \
        --charts "$charts_dir" \
        --targets "$(IFS=,; echo "${TARGETS[*]}")"
    
    log "Report generated: ${compare_dir}/final_report.html"
    log "Charts saved to: $charts_dir"
    
    # Open report in browser (macOS)
    if [[ "$(uname)" == "Darwin" ]]; then
        open "${compare_dir}/final_report.html"
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target)
                TARGETS+=("$2")
                shift 2
                ;;
            --duration)
                DURATION="$2"
                shift 2
                ;;
            --warmup)
                WARMUP="$2"
                shift 2
                ;;
            --sizes)
                SIZES="$2"
                shift 2
                ;;
            --concurrency)
                CONCURRENCY="$2"
                shift 2
                ;;
            --iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            --objects)
                OBJECTS="$2"
                shift 2
                ;;
            --compare)
                DO_COMPARE=true
                shift
                ;;
            --report)
                DO_REPORT=true
                shift
                ;;
            --report-last)
                # Generate report from the last run for a single target
                REPORT_LAST_TARGET="$2"
                shift 2
                ;;
            --use-latest)
                USE_LATEST=true
                shift
                ;;
            --skip-cleanup)
                SKIP_CLEANUP=true
                shift
                ;;
            --heartbeat-interval)
                HEARTBEAT_INTERVAL="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

generate_report_from_last() {
    local target="$1"
    local latest_dir
    latest_dir=$(find "$RESULTS_DIR/$target" -maxdepth 1 -type d | sort -r | head -1)
    if [[ -z "$latest_dir" ]]; then
        error "No results found for target: $target"
    fi

    local merged_summary="$latest_dir/summary.json"
    if [[ ! -f "$merged_summary" ]]; then
        error "Summary file not found: $merged_summary"
    fi

    local charts_dir="$latest_dir/charts"
    mkdir -p "$charts_dir"

    python3 "${SCRIPT_DIR}/report.py" \
        --input "$merged_summary" \
        --output "$latest_dir/final_report.html" \
        --charts "$charts_dir" \
        --targets "$target"

    log "Report generated: $latest_dir/final_report.html"
}

main() {
    parse_arguments "$@"
    
    # If report-last was requested, generate it and exit immediately
    if [[ -n "${REPORT_LAST_TARGET:-}" ]]; then
        mkdir -p "$TARGETS_DIR" "$RESULTS_DIR"
        check_prerequisites
        generate_report_from_last "$REPORT_LAST_TARGET"
        exit 0
    fi

    # Create directories
    mkdir -p "$TARGETS_DIR" "$RESULTS_DIR"

    check_prerequisites
    
    # If --use-latest, skip benchmark runs
    if [[ "$USE_LATEST" == "false" ]]; then
        if [[ ${#TARGETS[@]} -eq 0 ]]; then
            error "No targets specified. Use --target aws --target other"
        fi
        
        # Validate all target configs first
        for target in "${TARGETS[@]}"; do
            check_target_config "$target"
        done
        
        # Run benchmarks
        for target in "${TARGETS[@]}"; do
            run_benchmark_suite "$target"
        done
    else
        if [[ ${#TARGETS[@]} -eq 0 ]]; then
            # Auto-detect targets from results directory
            TARGETS=($(ls -d "${RESULTS_DIR}"/*/ 2>/dev/null | xargs -n1 basename))
            if [[ ${#TARGETS[@]} -eq 0 ]]; then
                error "No existing results found and no targets specified"
            fi
            log "Auto-detected targets: ${TARGETS[*]}"
        fi
    fi
    
    # Generate comparison if requested
    local compare_dir=""
    if [[ "$DO_COMPARE" == "true" ]] || [[ "$DO_REPORT" == "true" ]]; then
        if [[ ${#TARGETS[@]} -lt 2 ]]; then
            warn "Comparison requires at least 2 targets, skipping comparison"
        else
            compare_dir=$(generate_comparison)
        fi
    fi
    
    # Generate report if requested
    if [[ "$DO_REPORT" == "true" ]]; then
        if [[ -z "$compare_dir" ]]; then
            if [[ ${#TARGETS[@]} -eq 1 ]]; then
                generate_report_from_last "${TARGETS[0]}"
            else
                compare_dir=$(find "$RESULTS_DIR" -maxdepth 1 -name "compare_*" -type d | sort -r | head -1)
                if [[ -z "$compare_dir" ]]; then
                    error "No comparison data found. Run with --compare first"
                fi
                generate_report "$compare_dir"
            fi
        else
            generate_report "$compare_dir"
        fi
    fi

    # Generate report from last run for a target if requested
    if [[ -n "${REPORT_LAST_TARGET:-}" ]]; then
        generate_report_from_last "$REPORT_LAST_TARGET"
        exit 0
    fi
    
    # Auto-generate graphs for the last run if we just ran benchmarks
    if [[ "$USE_LATEST" == "false" ]] && [[ ${#TARGETS[@]} -gt 0 ]]; then
        log "Generating performance graphs..."
        for target in "${TARGETS[@]}"; do
            local target_dir="${RESULTS_DIR}/${target}"
            local latest_run=$(ls -dt "${target_dir}"/*/ 2>/dev/null | head -1)
            if [[ -n "$latest_run" ]]; then
                log "Creating graphs for ${target}: ${latest_run}"
                if python3 "${SCRIPT_DIR}/graph_results.py" "$latest_run" 2>&1; then
                    log "✓ Graphs created in: ${latest_run}"
                else
                    warn "Failed to generate graphs (install matplotlib/seaborn in a venv)"
                fi
            fi
        done
    fi
    
    log "Benchmark run completed successfully"
}

# Trap cleanup on exit
trap 'log "Benchmark interrupted"' INT TERM

main "$@"
