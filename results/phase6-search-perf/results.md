# Phase 6 — Search Performance Results

---

## Test Setup

| Field | Value |
|-------|-------|
| Indexer count | |
| Search head count | |
| Data volume searched | |
| Search time range | |

## 6a. Cache vs No-Cache Comparison

Run the same searches at 100% cache (warm) and 0% cache (evicted).

| Search | Event count | 100% cache latency (s) | 0% cache latency (s) | Ratio |
|--------|-------------|------------------------|----------------------|-------|
| Search A (spl query) | | | | |
| Search B (spl query) | | | | |
| Search C (spl query) | | | | |

## 6b. Latency by Cache Percentage

Run the same representative search at 25%, 50%, 75%, 100% cache levels.

| Cache level | Latency (s) | Remote Storage Search Overhead (s) | Cache hits | Cache misses |
|-------------|-------------|------------------------------------|------------|--------------|
| 100% | | | | |
| 75% | | | | |
| 50% | | | | |
| 25% | | | | |

## MC Metrics

| Metric | Value |
|--------|-------|
| Remote Storage Search Overhead (avg, s) | |
| Cache Hit ratio (%) | |
| Peak download throughput during search (MB/s) | |

## Attached Files

Drop files into this folder (`results/phase6-search-perf/`):

- [ ] Job Inspector output for each search (`.json` / `.png` / `.jpg` / `.pdf`)
- [ ] MC SmartStore Activity screenshots during search runs (`.png` / `.jpg` / `.pdf`)

## Notes
