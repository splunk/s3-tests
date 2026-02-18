# Results Collection Guide

This directory contains templates for capturing and submitting results for every phase of the [SmartStore Partner Test Plan](../README.md).

## Directory Structure

```
results/
  00-env-info.md                 ← Fill in once (partner info, versions, topology)
  check_results.py               ← Run to check completeness before submitting
  test_check_results.py          ← Tests for check_results.py
  phase1-s3-compat/
    results.md                   ← Summary + attach JUnit XML + log from s3tests/reports/
  phase2-deployment/
    results.md                   ← Connectivity checks, MC screenshot
  phase3-functional/
    results.md                   ← Search before/after eviction, MC Bucket Activity
  phase4-migration/
    results.md                   ← Migration timeline, upload throughput, MC progress
  phase5-remote-store-perf/
    results.md                   ← Upload/download throughput, search latency by cache %
  phase6-search-perf/
    results.md                   ← Search latency (cache vs no cache, 25/50/75/100%)
  phase7-scale/
    results.md                   ← Same as phase 5/6 at scale indexer/ingest count
  phase8-multisite/
    results.md                   ← Per-scenario pass/fail, replication lag, object counts
```

---

## How to Use

**All commands below are run from the repo root.**

### Step 1 — Fill in environment info

Open `results/00-env-info.md` and fill in your company name, contact, Splunk version, storage vendor/version, and deployment topology. Do this once before starting any phase.

### Step 2 — Complete each phase

For each phase you run:
1. Fill in the tables in `results/phase<N>-*/results.md`.
2. Drop screenshots, logs, and exports directly into the same `phase*/` folder (no sub-folders needed).

### Step 3 — Check completeness at any time

```bash
python results/check_results.py
```

Prints a per-phase status — **COMPLETE**, **PARTIAL**, or **NOT STARTED** — listing every blank field, unanswered yes/no, missing required attachment, and any extra files already present. Ends with a **READY TO SUBMIT** / **NEARLY READY** / **NOT READY** verdict.

> You can also run it from inside the `results/` folder:
> ```bash
> cd results
> python check_results.py
> ```

### Step 4 — Package and send

Once all required phases show COMPLETE (or you want a checkpoint review):

```bash
./collect_results.sh
```

Run this from the **repo root**. It will:
- Auto-capture OS, Python, and git info → `results/00-env-info-auto.txt`
- Copy the latest Phase 1 JUnit XML and pytest log from `s3tests/reports/` → `results/phase1-s3-compat/`
- Warn about any phases that still have unfilled fields
- Create **`results-bundle-<YYYYMMDD-HHMMSS>.tar.gz`** in the repo root

Send that `.tar.gz` to your Splunk partner team contact.

---

## What Goes Where

| Phase | How results are captured | Files to drop in the folder |
|-------|-------------------------|-----------------------------|
| Phase 1 | Run `./s3tests/run_core_s3_tests.sh` — output goes to `s3tests/reports/` automatically | `collect_results.sh` copies them; or copy manually: `junit-*.xml`, `pytest-*.log` |
| Phase 2 | Manual | MC screenshot (`.png`/`.jpg`/`.pdf`), CLI output (`.txt`/`.log`) |
| Phase 3 | Manual | MC Bucket Activity screenshot, CLI output |
| Phase 4 | Manual | MC Migration Progress screenshot, `splunkd.log` excerpt |
| Phase 5 | Manual | MC charts screenshot, Job Inspector export (`.json`/`.png`/`.pdf`), storage vendor export (`.csv`) |
| Phase 6 | Manual | Job Inspector output, MC charts screenshot |
| Phase 7 | Manual | Same as Phase 5/6 at scale |
| Phase 8 | Manual | MC screenshots per scenario, `splunkd.log`, storage replication dashboard export |

Accepted formats: screenshots (`.png` `.jpg` `.jpeg` `.gif` `.webp` `.pdf`), logs (`.log` `.txt`), data exports (`.csv` `.json` `.xml`). `check_results.py` detects and lists every file present.
