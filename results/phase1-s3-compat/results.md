# Phase 1 — S3 API Compatibility Results

Run `./s3tests/run_core_s3_tests.sh` from the repo root (see [s3tests/README.rst](../../s3tests/README.rst)).
The script writes the JUnit XML and full log to `s3tests/reports/`. Copy those two files here after the run.

---

## Run Summary

| Field | Value |
|-------|-------|
| Run date / time | |
| Splunk Enterprise version | |
| Object storage vendor + version | |
| S3 endpoint used | |
| s3tests/splunk.conf `[s3 main] host` | |
| s3tests/splunk.conf `[s3 main] port` | |
| is_secure | |

## Test Counts

| Metric | Count |
|--------|-------|
| Tests collected | |
| Tests passed | |
| Tests failed | |
| Tests errored | |
| Tests skipped (skip_for_splunk) | |
| Tests deselected by script | |

## Attached Files

Drop files into this folder (`results/phase1-s3-compat/`):

- [ ] JUnit XML — copy `s3tests/reports/junit-<timestamp>.xml` here (`.xml`)
- [ ] pytest log — copy `s3tests/reports/pytest-<timestamp>.log` here (`.log` / `.txt`)

## Unexpected Failures

List any test failures that are NOT in the deselect list and NOT connectivity/config errors:

| Test name | Error summary | Suspected cause |
|-----------|---------------|-----------------|
| | | |

## Notes

<!-- Any deviations, errors during setup, or vendor-specific observations -->
