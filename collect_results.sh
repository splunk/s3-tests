#!/usr/bin/env bash
# collect_results.sh — Collects all SmartStore partner test results into a
# single tar.gz bundle for submission to the Splunk partner team.
#
# Usage (from repo root):
#   ./collect_results.sh
#
# Output:
#   results-bundle-<YYYYMMDD-HHMMSS>.tar.gz  in the repo root
#
# What it does:
#   1. Writes auto-detected system info to results/00-env-info-auto.txt
#   2. Copies the latest Phase 1 JUnit XML and pytest log into results/phase1-s3-compat/
#   3. Packages the entire results/ directory into a single archive

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUNDLE_NAME="results-bundle-${TIMESTAMP}.tar.gz"
RESULTS_DIR="${SCRIPT_DIR}/results"
S3TESTS_REPORTS="${SCRIPT_DIR}/s3tests/reports"
AUTO_INFO="${RESULTS_DIR}/00-env-info-auto.txt"

echo "==> SmartStore Partner Test Results Collector"
echo "    Repo root : ${SCRIPT_DIR}"
echo "    Bundle    : ${BUNDLE_NAME}"
echo ""

# ---------------------------------------------------------------------------
# 1. Auto-collect system info
# ---------------------------------------------------------------------------
echo "--- Collecting system info ---"
{
  echo "Collected: $(date)"
  echo ""
  echo "=== OS ==="
  uname -a 2>/dev/null || true
  if [[ -f /etc/os-release ]]; then cat /etc/os-release; fi
  echo ""
  echo "=== Python ==="
  python3 --version 2>&1 || python --version 2>&1 || echo "(python not found)"
  echo ""
  echo "=== pip ==="
  pip3 --version 2>&1 || pip --version 2>&1 || echo "(pip not found)"
  echo ""
  echo "=== pytest ==="
  if command -v pytest &>/dev/null; then pytest --version 2>&1; else echo "(pytest not found in PATH — activate venv first)"; fi
  echo ""
  echo "=== Hostname / Network ==="
  hostname 2>/dev/null || true
  echo ""
  echo "=== Git commit ==="
  git -C "${SCRIPT_DIR}" log -1 --oneline 2>/dev/null || echo "(not a git repo)"
} > "${AUTO_INFO}"
echo "    Written: results/00-env-info-auto.txt"

# ---------------------------------------------------------------------------
# 2. Copy latest Phase 1 test outputs (if they exist)
# ---------------------------------------------------------------------------
PHASE1_DEST="${RESULTS_DIR}/phase1-s3-compat"
mkdir -p "${PHASE1_DEST}"

if [[ -d "${S3TESTS_REPORTS}" ]]; then
  # JUnit XML — pick the newest
  LATEST_XML=$(ls -t "${S3TESTS_REPORTS}"/junit-*.xml 2>/dev/null | head -1 || true)
  if [[ -n "${LATEST_XML}" ]]; then
    cp "${LATEST_XML}" "${PHASE1_DEST}/"
    echo "    Copied: $(basename "${LATEST_XML}") → results/phase1-s3-compat/"
  else
    echo "    (no JUnit XML found in s3tests/reports/ — run ./s3tests/run_core_s3_tests.sh first)"
  fi

  # Pytest log — pick the newest
  LATEST_LOG=$(ls -t "${S3TESTS_REPORTS}"/pytest-*.log 2>/dev/null | head -1 || true)
  if [[ -n "${LATEST_LOG}" ]]; then
    cp "${LATEST_LOG}" "${PHASE1_DEST}/"
    echo "    Copied: $(basename "${LATEST_LOG}") → results/phase1-s3-compat/"
  else
    echo "    (no pytest log found in s3tests/reports/ — run ./s3tests/run_core_s3_tests.sh first)"
  fi
else
  echo "    (s3tests/reports/ not found — run ./s3tests/run_core_s3_tests.sh first)"
fi

# ---------------------------------------------------------------------------
# 3. Check that the required template files have been started
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking results templates ---"
MISSING_FILLS=0
for phase_dir in "${RESULTS_DIR}"/phase*/; do
  results_file="${phase_dir}results.md"
  if [[ -f "${results_file}" ]]; then
    # Count fields that are still blank (table rows ending in "| |")
    blanks=$(grep -c '| |' "${results_file}" 2>/dev/null || true)
    phase_name=$(basename "${phase_dir}")
    if [[ "${blanks}" -gt 4 ]]; then
      echo "    WARNING: ${phase_name}/results.md has ${blanks} unfilled fields"
      MISSING_FILLS=$((MISSING_FILLS + 1))
    else
      echo "    OK      : ${phase_name}/results.md"
    fi
  fi
done

if [[ "${MISSING_FILLS}" -gt 0 ]]; then
  echo ""
  echo "    ${MISSING_FILLS} phase(s) still have mostly blank results."
  echo "    Bundle will be created anyway — fill in the templates and re-run."
fi

# ---------------------------------------------------------------------------
# 4. Create the tar.gz bundle
# ---------------------------------------------------------------------------
echo ""
echo "--- Building bundle ---"
cd "${SCRIPT_DIR}"
tar -czf "${BUNDLE_NAME}" results/

echo ""
echo "==> Bundle ready: ${SCRIPT_DIR}/${BUNDLE_NAME}"
echo ""
echo "    Send this file to your Splunk partner team contact."
echo "    Make sure you have filled in at minimum:"
echo "      • results/00-env-info.md      (partner/version/topology info)"
echo "      • results/phase1-s3-compat/results.md  (after running s3tests)"
echo "      • Any other phases you have completed."
