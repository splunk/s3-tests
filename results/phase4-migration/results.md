# Phase 4 — Migration Testing Results

---

## Pre-Migration Setup

| Field | Value |
|-------|-------|
| Indexer count | |
| Data volume ingested before migration | |
| Ingest rate (TB/day) | |
| Days of data | |
| Bucket size (`maxDataSize`) | auto_high_volume (10 GB) |

## Migration Steps Completed

| Step | Completed | Notes |
|------|-----------|-------|
| Maintenance mode enabled on CM | yes / no | |
| All indexers stopped | yes / no | |
| SmartStore config set on CM | yes / no | |
| CM bundle push executed | yes / no | |
| All indexers started | yes / no | |
| Warm/cold buckets uploaded | yes / no | |
| SF = RF set | yes / no | |
| Cluster valid and complete | yes / no | |

## Migration Completion Confirmation

MC Migration Progress dashboard captured: **yes / no**  
Attach: `mc-migration-progress.png`

REST query confirming all buckets migrated:
```
| rest splunk_server=idx1 /services/admin/cacheman | search cm:bucket.stable=0 | stats count
```
Result (must be **0**): ____

## Migration Performance

| Metric | Value |
|--------|-------|
| Migration start time | |
| Migration end time | |
| Total migration duration | |
| Peak upload throughput (per indexer, MB/s) | |
| Peak upload throughput (deployment-wide, MB/s) | |
| Average upload throughput (per indexer, MB/s) | |
| Average upload throughput (deployment-wide, MB/s) | |

## Post-Migration Search Verification

| Check | Result |
|-------|--------|
| Searches return same results as pre-migration | yes / no |
| MC shows no migration errors | yes / no |

## Attached Files

Drop files into this folder (`results/phase4-migration/`):

- [ ] MC Migration Progress screenshot (`.png` / `.jpg` / `.pdf`)
- [ ] splunkd.log excerpt — SmartStore upload activity during migration (`.log` / `.txt`)
- [ ] MC SmartStore Activity dashboard screenshot post-migration (`.png` / `.jpg` / `.pdf`)

## Notes
