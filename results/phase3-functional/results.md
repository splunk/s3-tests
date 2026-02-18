# Phase 3 — Functional Testing Results

---

## 3a. Data Ingestion and Transition to Remote Storage

| Check | Result |
|-------|--------|
| Data ingested (volume / duration) | |
| Hot buckets rolled to warm | yes / no |
| Warm buckets uploaded to remote storage | yes / no |

CLI output confirming uploads (abbreviated):
```
<!-- splunk cmd splunkd rfs -- ls --starts-with volume:remote_store -->
```

## 3b. Search Verification (before and after eviction)

| Search | Time range | Events (in-cache) | Events (after evict) | Match? |
|--------|-----------|------------------|--------------------|--------|
| Search 1 | | | | yes / no |
| Search 2 | | | | yes / no |
| Search 3 | | | | yes / no |

## 3c. MC Bucket Activity

- MC shows upload operations after ingest: **yes / no**
- MC shows download operations after eviction + search: **yes / no**

Attach MC screenshot: `mc-bucket-activity.png`

## 3d. Data Retention / Frozen

| Check | Result |
|-------|--------|
| Retention policy updated (index + maxTotalDataSizeMB or frozenTimePeriodInSecs) | |
| Buckets removed from local indexers | yes / no |
| Buckets removed from remote storage (or delete markers present) | yes / no |
| Versioning / delete markers observed (if applicable) | yes / no |

## Attached Files

Drop files into this folder (`results/phase3-functional/`):

- [ ] MC Bucket Activity screenshot (`.png` / `.jpg` / `.pdf`)
- [ ] CLI output showing uploaded buckets (`.txt` / `.log`)

## Notes
