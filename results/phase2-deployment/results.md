# Phase 2 — Deployment Results

---

## Connectivity Checks

### MC: Remote Storage Connectivity panel

- Panel location: **Indexing → SmartStore → SmartStore Activity: Deployment**
- Status shown: **Online / Offline / N/A**

Attach a screenshot: `mc-remote-storage-connectivity.png`

### CLI: RFS ls

Run from each indexer:
```bash
splunk cmd splunkd rfs -- ls --starts-with volume:remote_store
```

Paste abbreviated output (first 10 lines or so):

```
<!-- paste output here -->
```

## server.conf Settings Confirmed

| Setting | Expected | Actual |
|---------|----------|--------|
| `parallelIngestionPipelines` | 2 | |
| `tsidxWritingLevel` | 4 | |
| `max_cache_size` | 100000 | |

## Attached Files

Drop files into this folder (`results/phase2-deployment/`). Any of these formats are accepted:

- [ ] MC Remote Storage Connectivity screenshot (`.png` / `.jpg` / `.pdf`)
- [ ] Splunk logs — splunkd.log excerpt for SmartStore startup (`.log` / `.txt`)

## Notes
