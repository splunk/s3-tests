#!/usr/bin/env python3
"""
check_results.py — Checks the results/ directory for completeness.

Usage (run from the repo root or from inside results/):
    python results/check_results.py

Prints a per-phase status report showing:
  - Which phases are COMPLETE / PARTIAL / NOT STARTED
  - Which table fields are still blank
  - Which required attachments are missing or present
  - Any extra files found in each phase folder
"""

import re
from pathlib import Path

SCRIPT_DIR  = Path(__file__).resolve().parent
RESULTS_DIR = SCRIPT_DIR  # script lives inside results/

PHASES = [
    ("env",    RESULTS_DIR / "00-env-info.md",               "Environment & Contact Info",     False),
    ("phase1", RESULTS_DIR / "phase1-s3-compat",             "Phase 1 — S3 API Compatibility", True),
    ("phase2", RESULTS_DIR / "phase2-deployment",            "Phase 2 — Deployment",           True),
    ("phase3", RESULTS_DIR / "phase3-functional",            "Phase 3 — Functional Testing",   True),
    ("phase4", RESULTS_DIR / "phase4-migration",             "Phase 4 — Migration Testing",    True),
    ("phase5", RESULTS_DIR / "phase5-remote-store-perf",     "Phase 5 — Remote Store Perf",    True),
    ("phase6", RESULTS_DIR / "phase6-search-perf",           "Phase 6 — Search Performance",   True),
    ("phase7", RESULTS_DIR / "phase7-scale",                 "Phase 7 — Scale Testing",        True),
    ("phase8", RESULTS_DIR / "phase8-multisite",             "Phase 8 — Multi-Site",           True),
]

SCREENSHOT_GLOBS = ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.tiff"]
LOG_GLOBS        = ["*.log", "*.txt"]

# Required attachments per phase folder: (label, [accepted glob patterns])
# Any one matching file satisfies the requirement.
REQUIRED_ATTACHMENTS = {
    "phase1-s3-compat": [
        ("JUnit XML test report",                     ["*.xml"]),
        ("pytest log",                                LOG_GLOBS),
    ],
    "phase2-deployment": [
        ("MC Remote Storage Connectivity screenshot", SCREENSHOT_GLOBS),
    ],
    "phase3-functional": [
        ("MC Bucket Activity screenshot",             SCREENSHOT_GLOBS),
    ],
    "phase4-migration": [
        ("MC Migration Progress screenshot",          SCREENSHOT_GLOBS),
    ],
    "phase5-remote-store-perf": [
        ("MC SmartStore Activity screenshot",         SCREENSHOT_GLOBS),
    ],
    "phase6-search-perf": [
        ("MC or Job Inspector screenshot",            SCREENSHOT_GLOBS),
    ],
    "phase7-scale": [
        ("MC SmartStore Activity screenshot",         SCREENSHOT_GLOBS),
    ],
    "phase8-multisite": [
        ("MC screenshot — at least one scenario",     SCREENSHOT_GLOBS),
    ],
}

# File types that belong to the template itself, never counted as attachments
IGNORE_EXTENSIONS = {".md", ".py", ".pyc", ".sh"}


# ---------------------------------------------------------------------------
# Helper functions (importable for testing)
# ---------------------------------------------------------------------------

def blank_cells(text):
    """Count empty Markdown table cells: | |
    Uses [ \\t] (horizontal whitespace only) so consecutive table rows
    like '| value |\\n| next |' are not falsely matched.
    """
    return len(re.findall(r'\|[ \t]*\|', text))


def unchecked_boxes(text):
    """Count unticked attachment checkboxes: - [ ]"""
    return len(re.findall(r'- \[ \]', text))


def undecided_yes_no(text):
    """Count fields still showing the 'yes / no' placeholder."""
    return len(re.findall(r'\byes / no\b', text, re.IGNORECASE))


def check_attachments(phase_dir):
    """Scan a phase folder for required and extra files.

    Returns:
        found   — list of (label, [filenames]) for requirements that are met
        missing — list of label strings for requirements with no matching file
        extra   — list of filenames present but not part of any requirement
    """
    requirements = REQUIRED_ATTACHMENTS.get(phase_dir.name, [])

    all_files = {
        f.name for f in phase_dir.iterdir()
        if f.is_file() and f.suffix.lower() not in IGNORE_EXTENSIONS
    }

    accounted_for = set()
    found, missing = [], []

    for label, globs in requirements:
        matched = sorted({
            f.name
            for g in globs
            for f in phase_dir.glob(g)
            if f.suffix.lower() not in IGNORE_EXTENSIONS
        })
        if matched:
            found.append((label, matched))
            accounted_for.update(matched)
        else:
            missing.append(label)

    extra = sorted(all_files - accounted_for)
    return found, missing, extra


def phase_status(blanks, unchecked, undecided, missing_count):
    """Classify a phase as COMPLETE, PARTIAL, or NOT STARTED."""
    if blanks == 0 and unchecked == 0 and undecided == 0 and missing_count == 0:
        return "COMPLETE"
    if blanks > 8 and unchecked > 2 and missing_count > 0:
        return "NOT STARTED"
    return "PARTIAL"


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def run_report():
    out = []
    p = out.append

    p("=" * 68)
    p("SmartStore Partner Results — Completeness Check")
    p("=" * 68)
    p("")

    not_started, partial, complete = [], [], []

    for _key, path, label, is_dir in PHASES:
        p(f"### {label}")

        results_md = (path / "results.md") if is_dir else path

        if not results_md.exists():
            p("  Status  : NOT STARTED — results.md not found")
            p("")
            not_started.append(label)
            continue

        text = results_md.read_text(encoding="utf-8")
        b  = blank_cells(text)
        u  = unchecked_boxes(text)
        yn = undecided_yes_no(text)

        found, missing, extra = [], [], []
        if is_dir:
            found, missing, extra = check_attachments(path)

        status = phase_status(b, u, yn, len(missing))
        p(f"  Status  : {status}")

        if b:
            p(f"  Blanks  : {b} table field(s) not filled in")
        if yn:
            p(f"  Pending : {yn} yes/no field(s) still showing placeholder")
        if u:
            p(f"  Pending : {u} attachment checkbox(es) still unchecked")

        for lbl, files in found:
            p(f"  Found   : {lbl}")
            for fn in files:
                p(f"            • {fn}")
        for lbl in missing:
            p(f"  MISSING : {lbl}")
        if extra:
            p(f"  Extra   : {len(extra)} additional file(s) in folder:")
            for fn in extra:
                p(f"            • {fn}")

        p("")

        if status == "COMPLETE":
            complete.append(label)
        elif status == "NOT STARTED":
            not_started.append(label)
        else:
            partial.append(label)

    total = len(PHASES)
    p("=" * 68)
    p("SUMMARY")
    p("=" * 68)
    p(f"  Complete    : {len(complete)}/{total}")
    p(f"  Partial     : {len(partial)}/{total}")
    p(f"  Not started : {len(not_started)}/{total}")
    p("")

    if not_started:
        p("Not started:")
        for x in not_started:
            p(f"  - {x}")
    if partial:
        p("Partial — still needs data or attachments:")
        for x in partial:
            p(f"  ~ {x}")
    if complete:
        p("Complete:")
        for x in complete:
            p(f"  + {x}")
    p("")

    if len(complete) == total:
        p("READY TO SUBMIT")
    elif not not_started:
        p("NEARLY READY — finish the partial phases before submitting")
    else:
        p("NOT READY — complete the phases marked 'Not started' before submitting")

    print("\n".join(out))


if __name__ == "__main__":
    run_report()
