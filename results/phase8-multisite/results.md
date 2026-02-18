# Phase 8 — Multi-Site Failure/Recovery Results

---

## Test Setup

| Field | Value |
|-------|-------|
| Setup type (Basic / Scale) | |
| Indexer count per site | |
| Total indexer count | |
| Ingest rate (TB/day) | |
| Replication lag (max observed, ms) | |

## Scenario Results

Complete one table row per scenario from the failure/recovery table.

| Scenario | Searches returned correct results? | Upload to correct RS? | Object counts RS1 = RS2? | Replication lag (peak, ms) | Replication catchup time (min) | Notes |
|----------|------------------------------------|-----------------------|--------------------------|---------------------------|-------------------------------|-------|
| Stable mode | yes / no | yes / no | yes / no | | N/A | |
| Site1 failure | yes / no | yes / no | N/A (RS1 down) | N/A | N/A | |
| Site1 recovery | yes / no | yes / no | yes / no | | | |
| RS1 is Down | yes / no | yes / no | N/A (RS1 down) | N/A | N/A | |
| RS1 is UP | yes / no | yes / no | yes / no | | | |

## Search Results (per searchA–G)

| Search | Scenario | In-cache event count | Post-evict event count | Match? |
|--------|----------|---------------------|----------------------|--------|
| searchA | Stable | | | |
| searchB (delete) | Stable | | | |
| searchC (RA/DMA) | Stable | | | |
| searchD | Site1 failure | | | |
| searchE | Site1 recovery | | | |
| searchF | RS1 Down | | | |
| searchG | RS1 UP | | | |

## Replication Performance

| Metric | Value |
|--------|-------|
| Peak replication lag (ms) | |
| Average replication lag (ms) | |
| Peak replication throughput (MB/s) | |
| Average replication throughput (MB/s) | |
| Max network throughput per store (MB/s) | |

## Object Count Comparison (RS1 vs RS2)

| Checkpoint | RS1 object count | RS2 object count | Latest event timestamp RS1 | Latest event timestamp RS2 |
|------------|------------------|------------------|-----------------------------|----------------------------|
| After stable mode | | | | |
| After site1 failure | | | | |
| After site1 recovery | | | | |
| After RS1 down | | | | |
| After RS1 up | | | | |

## Attached Files

Drop files into this folder (`results/phase8-multisite/`):

- [ ] MC SmartStore Activity screenshot — one per scenario (`.png` / `.jpg` / `.pdf`)
- [ ] Splunk logs during failure/recovery events (`.log` / `.txt`)
- [ ] Storage vendor replication dashboard per scenario (`.png` / `.jpg` / `.pdf` / `.csv`)

## Notes
