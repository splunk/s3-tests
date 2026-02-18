# Splunk Partner Test Plan for SmartStore

**Date:** 02/10/2025  
This document outlines the testing process for validating Splunk’s SmartStore feature against an S3 API–compatible object storage system.

---

## Before You Begin

- **Required skills:** Strong knowledge of Splunk storage architecture; ability to deploy and administer advanced Splunk Enterprise features (including multi-site clustering); general knowledge of searching and indexing in Splunk Enterprise.
- **Pre-read:** Many details must be understood before starting. At a high level, this plan guides you to: connect Splunk to your remote object storage; deploy Splunk in a distributed/multi-site configuration; enable collection of 1 TB of test data; complete functional and baseline measurements of search/index performance.
- **Deliverables:** All measurements and outcomes must be shared with Splunk. Performance tests are **informational only** and do not represent real-world workloads.
- **Questions:** Review the [Expected Test Outcomes](#expected-test-outcomes) at the end, and reach out to the Splunk partner team for any clarifications.

---

## 1. Splunk SmartStore API Compatibility

Splunk SmartStore uses S3 APIs to connect to remote object storage. Only a **subset** of S3 APIs is used by SmartStore. To determine whether your object store is S3-compliant and supports the APIs used by SmartStore:

| Step | Action |
|------|--------|
| **a** | Use the S3 compatibility checking tool in this repo: everything lives in **s3tests/** (tests, **run_core_s3_tests.sh**, config samples, setup, tox, requirements) — see [splunk/s3-tests](https://github.com/splunk/s3-tests). |
| **b** | Follow **[s3tests/README.rst](s3tests/README.rst)**: create a venv at repo root, copy `s3tests/splunk.conf` from the sample, and run `./s3tests/run_core_s3_tests.sh` from the repo root. |
| **c** | Capture the results (logs) from the S3 API compatibility tests and **share with the Splunk partner team (required)**. |

---

## 2. Splunk SmartStore Deployment Overview

| Step | Action |
|------|--------|
| **a** | Review [Splunk SmartStore system requirements](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/SmartStoresystemrequirements). |
| **b** | Determine security/access policies to allow access to the remote storage system. |
| **c** | Set up the remote storage system with network connectivity to **all indexers** on the Splunk SmartStore deployment (per your storage vendor’s instructions). |
| **d** | Set up the Splunk SmartStore deployment with the **latest version of Splunk Enterprise**. |
| **e** | Set up/install the **Splunk Monitoring Console (MC)** as part of the deployment. |
| **f** | **Confirm connectivity** between Splunk SmartStore and remote storage: |
| | • **MC:** Navigate to **Indexing → SmartStore → SmartStore Activity: Deployment** and verify the **Remote Storage Connectivity** panel shows **online**. |
| | • **CLI** (run from one of the indexers): `splunk cmd splunkd rfs -- ls --starts-with volume:remote_store` |

### Keep these settings the same for all tests

Ensure the following are set (and unchanged) across tests:

**server.conf** (indexer / CM as applicable):

```ini
[general]
parallelIngestionPipelines = 2

[indexer]
tsidxWritingLevel = 4

[cachemanager]
max_cache_size = 100000
```

---

## 3. Functional Testing (5+ node indexer cluster)

### 3a. Verify data ingestion and transition to remote storage

- Ingest new data into Splunk (all new data is created as **hot** data).
- **Roll hot data to warm:** On each indexer run:
  ```bash
  splunk _internal call /data/indexes/<index_name>/roll-hot-buckets -auth <admin>:<password>
  ```
- **Verify all rolled buckets were uploaded to remote storage:**
  1. Use **dbinspect** to list rolled buckets.
  2. Use the Splunk CLI to confirm objects are in the remote store: from an indexer run  
     `splunk cmd splunkd rfs -- ls --starts-with volume:remote_store` and confirm paths match the rolled buckets from dbinspect.
  3. Optionally use the storage vendor CLI to list bucket contents and correlate.

### 3b. Verify searches on recent and old data

- Run searches that include both hot and warm data.
- **Evict warm data** from indexers and run the **same search** again; verify results are **identical** (same time range). To evict, run the evict REST endpoint **twice** (e.g. per indexer):
  - By cache id: `services/admin/cacheman/<cid>/evict`
  - Or evict all (run twice):  
    `curl -ku admin:changeme "https://localhost:8089/services/admin/cacheman/_evict" -d path=/path_to_cache/ -d mb=99999999999`  
  - Recommended (run twice per indexer):  
    `/opt/splunk/bin/splunk _internal call /services/admin/cacheman/_evict -post:mb 1000000000 -post:path /opt/splunk/var/lib/splunk -method POST`

### 3c. Confirm operational visibility in the Monitoring Console

- For steps 3a and 3b, verify the MC shows upload and download operations in the **Bucket Activity** dashboard panel (**Indexing → SmartStore → SmartStore Activity: Deployment**).

### 3d. Verify data retention

- Update data retention for a specific index to trigger rollover from warm/cold to **frozen**.
- Verify older buckets are removed from local indexers and remote storage. If versioning is supported, data in remote storage may only be **marked deleted** (delete markers) and not physically removed.

---

## 4. Migration Testing (7+ node indexer cluster)

| Step | Action |
|------|--------|
| **a** | Configure a **non-SmartStore** indexer cluster with local storage and `maxDataSize=auto_high_volume` (10 GB bucket size). |
| **b** | Ingest **10 or more days** of data at **1 TB/day or higher**. |
| **c** | Follow the official steps to [migrate an existing indexer cluster to SmartStore](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/MigratetoSmartStore): |
| | • Enable maintenance mode on the cluster master |
| | • Stop all indexers |
| | • Set up configuration on the CM to enable SmartStore for all indexes |
| | • Execute CM bundle push |
| | • Start all indexers |
| | • Wait for all warm/cold buckets to upload to remote storage |
| | • Make cluster-wide config changes so **SF = RF** |
| | • Confirm the cluster is valid and complete (replication and search factors met). |
| **d** | Confirm migration completion: **MC → SmartStore → SmartStore Activity: Deployment** (enable **Show Migration Progress**); capture the **Migration Progress** dashboard. Confirm: `\| rest splunk_server=idx1 ... /services/admin/cacheman \| search cm:bucket.stable=0 \| stats count` **returns 0**. |
| **e** | Measure upload performance via the SmartStore monitoring console dashboards. |
| **f** | Capture all Splunk logs and MC snapshots. **Required log paths:** |
| | • `$SPLUNK_HOME/var/log/splunk/splunkd.log` |
| | • `$SPLUNK_HOME/var/log/splunk/splunkd_utility.log` |
| | • `$SPLUNK_HOME/var/log/splunk/audit.log` |

---

## 5. Remote Store Performance Testing (7+ node indexer cluster)

| Step | Action |
|------|--------|
| **a** | Configure the SmartStore cache (local storage on all indexers) to hold **at least 10 days** of data (varies with ingest volume). |
| **b** | Ensure **maxDataSize=auto** (750 MB bucket size). If not, change on the CM and push to all indexers. |
| **c** | **Upload performance:** Ingest at 1 TB/day or higher; roll all hot buckets to warm (see 3a). Capture **peak and average upload throughput** per instance and deployment-wide from the SmartStore MC dashboards; capture logs and MC snapshots. |
| **d** | **Download performance:** Evict all data from the cache by running the evict CLI **twice** on each indexer: |
| | `splunk _internal call /services/admin/cacheman/_evict -post:mb 1000000000 -post:path $SPLUNK_DB -method POST` |
| | *Note:* Evict does not immediately remove data from disk; buckets are marked evictable. Running twice is still required per Splunk guidance. Then run a search that downloads buckets from the remote store. Capture **peak and average download throughput** per instance and deployment-wide. Use these **four MC dashboards** under **Indexing → SmartStore:** |
| | • SmartStore Activity: Instance |
| | • SmartStore Activity: Deployment |
| | • SmartStore Cache Performance: Instance |
| | • SmartStore Cache Performance: Deployment |
| | Capture **both** screenshots and the data behind the panels. Log paths: `splunkd.log`, `splunkd_utility.log`, `audit.log`. |

---

## 6. Search Performance

### 6a. Compare performance: data in cache vs not in cache

- *Note:* SmartStore may prefetch data; cache miss impact may be lower than expected.
- Measure search latency via **Job → Inspect Job** (e.g. *“This search has completed and has returned xyz results by scanning abc events in n seconds”*).
- Measure **Cache Hits/Misses** and **Remote Storage Search Overhead** in MC (**Indexing → SmartStore → SmartStore Activity: Deployment**).
- Capture Splunk logs and MC outputs.

### 6b. Compare performance at 25%, 50%, 75% in cache

- Evict all data from the cache (evict CLI twice; same command as in 5d):  
  `/opt/splunk/bin/splunk _internal call /services/admin/cacheman/_evict -post:mb 1000000000 -post:path /opt/splunk/var/lib/splunk -method POST`
- Run searches over time ranges that yield the target cache ratio. Measure latency (Job Inspector), Cache Hits/Misses, and bucket activity.

**Example sequence:**

| Step | Action |
|------|--------|
| 1 | Evict all cache (twice per indexer). |
| 2 | Search 5 days, then 20 days → **25% in cache**. |
| 3 | Evict all again. |
| 4 | Search 10 days, then 20 days → **50% in cache**. |
| 5 | Evict all again. |
| 6 | Search 15 days, then 20 days → **75% in cache**. |

---

## 7. Scale Testing

- Configure SmartStore cache to hold at least **10 days** of data.
- Scale ingest from **1 TB/day** to **2 TB/day** (do **not** increase SmartStore cache). Capture from MC:
  - Peak and average upload/download throughput per instance and deployment-wide
  - Cache hits and misses before and after scaling
  - **Skipped searches** (if any)
- Capture all Splunk logs and outputs (MC and SmartStore Performance App).

---

## 8. Multi-Site Testing

To protect against site/data center failures, Splunk can use **multi-site indexer clustering**. Multi-site with SmartStore has additional requirements; see the [Deploy multisite indexer cluster](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/MultisiteSmartStore) documentation.

### Supported topologies

1. **Public cloud** – hosted within a single region  
2. **On-premise** – hosted across data centers (DCs)  

The following focuses on **on-premise across DCs**.

### On-premise multi-site (two sites, two DCs)

- **Limit:** Two sites; each site in an on-premises data center. Each site has an **active object store** with **bi-directional replication** between them. One site has the **active cluster master**, the other a **standby**.
- **Replication:** Data uploaded to one remote store is replicated to the other by the storage vendor (typically **asynchronous** → replication lag). Lag varies with upload traffic, network bandwidth, and vendor behavior. Splunk does not add protection for data not yet replicated.
- **RPO:** In a permanent storage failure, data not replicated within the RPO window can be **permanently lost**.
- **Search:** Requests for data not in local cache may return **incomplete** results if that data is not yet on the local object store (replication lag). **Site affinity disabled** (e.g. `site=site0`) allows search heads to use peers on either site and can result in WAN traffic.

### Object storage requirements for multi-site (in addition to single-site)

| # | Requirement |
|---|-------------|
| 1 | Two-way replication between physical object stores (one direction active at a time). |
| 2 | Object versioning (e.g. S3-style); versioning by creation/mod time, not replication time. |
| 3 | Delete-marker replication support. |
| 4 | Upper bound / range for **max replication lag** between object stores. |

### Deployment requirements

| # | Requirement |
|---|-------------|
| 1 | Standby CM in each site; both CMs in sync (see [Cluster Manager redundancy](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/Handlemasternodefailure)). |
| 2 | Disable site affinity on all search heads: `site=site0` in server.conf. |
| 3 | Configure `site_replication_factor` and `site_search_factor` so each site holds at least one searchable copy of each bucket. |
| 4 | Forwarders load-balanced across all peers on all sites. |
| 5 | Remote object storage in each site with bi-directional replication; max replication lag within customer RPO. |
| 6 | Network latency between sites ≤ 300 ms (≤ 100 ms recommended). |
| 7 | SmartStore `remotePath` on **all** indexers points to the **same** URI/endpoint via a **VIP/GSLB**. |
| 8 | VIP/GSLB routes each site’s indexers to the **site-local** object store; on local store failure, reroutes to the other site’s store. |
| 9 | Splunk Enterprise 8.0.4+ or 7.3.6+; `max_cache_size` (server.conf) at default unless justified. |
| 10 | Topology limited to **two sites**. |

### Test setup

| Setup | Indexers | Ingest | Notes |
|-------|----------|--------|--------|
| **Basic** | 6+ (3+ per site) | 10+ days at 1 TB/day or higher | CM in site1, standby in site2; search heads `site=site0`; RS1 in site1, RS2 in site2; bidirectional replication and versioning; all indexers use same remotePath via VIP/GSLB; VIP routes to site-local store. |
| **Scale** | 15+ (7+ per site) | 10+ days at 2 TB/day or higher | Same as above, larger scale. |

### SmartStore Multi-Site Failure/Recovery Scenarios (full table)

The following table is the reference for Phase 8 multi-site testing. **Basic setup:** 6+ indexers (3+ per site), 10+ days at 1 TB/day or higher. **Scale setup:** 15+ indexers (7+ per site), 10+ days at 2 TB/day or higher.

| State | Setup | Indexers, CM, Search Heads | Remote Storage | Expected Behavior | Validation |
|-------|-------|---------------------------|----------------|-------------------|------------|
| **Stable mode** | Set up test deployment per "Test Setup" above. Enable bi-directional storage replication. Configure ALL indexers (master_uri) to point to CM in site1. Configure remotePath on ALL indexers to point to a single VIP/GSLB endpoint. Run ingest and search traffic from both sites. | Indexers in all sites UP and configured to point to CM in site1. remotePath on all indexers pointing to single VIP/GSLB endpoint. CM in site1 with standby CM in site2. site0 site affinity on search heads in both sites. | Both RS1 (site1) and RS2 (site2) active and UP. Two-way bi-replication between RS1 and RS2. Object versioning enabled on both remote object stores. | Ingest and searches active from both sites. Data from site1 indexers uploaded to RS1 then replicated to RS2. Indexers upload/download from their local remote store. Searches from non-primary sites may incur additional latency. Search requests for data impacted by replication lag and not in local cache may see partial results (temporary; within RPO). | Roll all hot buckets; verify site1→RS1, site2→RS2. Dump object count from RS1 and RS2; compare latest event timestamp. Capture Splunk and Storage metrics (8a, 8b). Run searchA from both sites and compare event count. Run searchB ("delete") and searchC (RA/DMA) from both sites and compare event count. Evict all cache on both sites; re-run searchA, searchB, searchC to validate same event counts. Capture object count from RS1 and RS2 between operations. Track replication lag. |
| **Site1 failure** | Continue from Stable. Ingest and search from both sites 15+ min more. Trigger site failure: CM, indexers, and RS1 in site1 DOWN. Activate CM in site2; update master_uri on site2 indexers to point to CM in site2. Continue ingest and search from site2 only. | Indexers, CM, and search heads in site1 DOWN. CM in site2 is active cluster master. Site2 indexers point to CM in site2. remotePath on site2 indexers → single VIP/GSLB. site0 on search heads in all sites. | RS1 DOWN. RS2 UP. Object storage replication between RS1 and RS2 halted. | Ingest and searches only from site2. RS2 may not have all recent data (replication lag). In-flight searches accessing failed site may return partial results. New search requests go to indexers in available DCs. Partial results possible for data in replication lag window (RPO). | Run searchD (normal + "delete" + RA/DMA) for data 30 min prior to and 30 min post site1 failure. Trigger hot bucket rollover; verify data uploaded to RS2. Dump and compare object count RS1 vs RS2 before/after failover; compare latest event timestamp. Capture Splunk and Storage metrics before/after. Re-run searchA, searchB, searchC, searchD (same timespan) to validate same event counts. Evict all cache on site2 indexers; re-run searchA–D to validate same counts. |
| **Site1 recovery** | Continue from Site1 failure. CM, indexers, and RS1 in site1 UP. Update master_uri on site1 indexers to point to CM in site2. Run ingest and search from both sites. | CM in site2 still active; CM in site1 is standby. Site1 and site2 indexers UP and configured to point to CM in site2. remotePath on all indexers → single VIP/GSLB. site0 on search heads. | Both RS1 and RS2 UP. Replication between RS1 and RS2 resumed. | Ingest and searches active from both sites. Replication includes data not replicated at failure time plus data written to RS2 while RS1 was down. Resync time depends on failure duration and replication throughput. | Run searchE (normal + "delete" + RA/DMA) for data 30 min prior to and 30 min post site1 recovery. Post recovery, trigger hot bucket rollover; verify data uploaded to both RS1 and RS2. Dump and compare object count and latest event timestamp before/after recovery. Capture Splunk and Storage metrics. Re-run searchA–E (same timespan); evict all cache on both sites; re-run searchA–E to validate same event counts. Track replication throughput and time to catchup. |
| **RS1 is Down** | Trigger remote storage failure: RS1 in site1 DOWN. Run ingest and search from site1 and site2. | CM in site2 active, CM in site1 standby. Site1 and site2 indexers point to CM in site2. remotePath → single VIP/GSLB. site0 on search heads. | RS1 in site1 DOWN. RS2 UP. Replication between RS1 and RS2 halted. | VIP/GSLB reroutes indexer traffic from site1 to RS2. Ingest and searches active from both sites. RS2 may not have all recent data. In-flight searches accessing RS1 may return partial results. | Run searchF (normal + "delete" + RA/DMA) for data 30 min prior to and 30 min post RS1 failure. Trigger hot bucket rollover; verify data from indexers in both sites uploaded to RS2. Dump and compare object count and latest event timestamp before/after RS1 down. Capture Splunk and Storage metrics. Re-run searchA, searchB, searchC, searchF; evict all cache on both sites; re-run searchA, searchB, searchC, searchF to validate same event counts. |
| **RS1 is UP** | RS1 in site1 now UP. Run ingest and search from both site1 and site2. | Same as RS1 is Down for indexers/CM/SH. | Both RS1 and RS2 UP. Replication between RS1 and RS2 resumed. | VIP/GSLB routes site1 indexer traffic to RS1. Ingest and searches active from both sites. Replication includes unreplicated data from failure period plus data written to RS2 while RS1 was down. Resync time depends on failure duration and throughput. | Run searchG (normal + "delete" + RA/DMA) for data 30 min prior to and 30 min post RS1 recovery. Post recovery, trigger hot bucket rollover; verify data from each site uploaded to site-local remote storage. Dump and compare object count and latest event timestamp before/after RS1 recovery. Capture Splunk and Storage metrics. Re-run searchA, searchB, searchC, searchF, searchG; evict all cache; re-run to validate same event counts. Track replication throughput and time to catchup. |

### Collection metrics (all scenarios)

- **Splunk:** Search latency (Job Inspector); Cache Hits/Misses; Remote Storage Search Overhead; Splunk logs and MC outputs; peak and average upload/download throughput per instance and deployment-wide; upload/download bucket counts. For evict-all (testing only): run _evict twice with high free space (e.g. `mb=1000000000`, `path=$SPLUNK_DB`).
- **Storage vendor:** Peak and average replication lag; peak and average replication throughput; max observed network throughput per store; periodic (e.g. hourly) total object count from both stores when UP.

### Multi-site migration testing

- Deploy 6+ indexers (3+ per site), non-SmartStore, local storage, `maxDataSize=auto_high_volume`.
- Ingest 10+ days at 1 TB/day or higher.
- Follow [Deployment Requirements](#deployment-requirements) and [migrate to SmartStore](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/MigratetoSmartStore): maintenance mode, stop indexers, enable SmartStore on CM, bundle push, start indexers, wait for uploads, set SF=RF, confirm cluster complete.
- Confirm migration (MC Show Migration Progress; `cm:bucket.stable=0` count = 0).
- Run index and search traffic from both sites and execute the multi-site stable-mode tests above.

### Miscellaneous (object storage questionnaire)

- Does the object store support S3 multi-part upload?
- Does it support versioning? When a versioned object is deleted, are older versions accessible via GET/LIST?
- Recommended network connectivity from indexers to object storage (and any reference diagrams)?
- Minimum purchasable storage unit (TB)?
- Max network bandwidth per storage unit? Can bandwidth scale with more units?
- How are access controls defined (IAM, access/secret key, etc.)?
- Max API (GET/PUT/LIST/DELETE) requests per second before throttling?
- Namespace/sharding recommendations for performance?
- Cross-site replication: sync or async? Minimum replication lag?
- Current GA version of object storage used for testing; upcoming releases?

---

## Collecting and Submitting Results

The `results/` directory provides a structured kit so every partner submits results in the **same format**, making comparison and review straightforward.

There are two ways to collect results — both are equally valid:

| Method | When to use |
|--------|-------------|
| **Script-assisted** (recommended) | Use `check_results.py` and `collect_results.sh` to verify completeness and package everything automatically. |
| **Manual** | Fill in the `results/phase*/results.md` templates and drop attachment files into each phase folder by hand, then zip or tar the `results/` folder yourself before sending. The folder structure and file naming must match the layout described in [results/README.md](results/README.md). |


### One-time setup

1. Clone this repo onto the machine you will use for testing.
2. Fill in **`results/00-env-info.md`** — your company name, Splunk version, storage vendor/version, and deployment topology.  This file is shared across all phases.

### Per-phase workflow

| Phase | What to do |
|-------|-----------|
| **Phase 1** | Run `./s3tests/run_core_s3_tests.sh` (see [s3tests/README.rst](s3tests/README.rst)). The script auto-saves a JUnit XML and full pytest log to `s3tests/reports/`. |
| **Phases 2–8** | After completing each phase, open `results/phase<N>-*/results.md` and fill in the tables. Add screenshots / log excerpts to the same folder. |

The `results/` directory contains a pre-built template for every phase:

```
results/
  00-env-info.md              ← fill in once (versions, topology, contact)
  check_results.py            ← run at any time to check completeness
  phase1-s3-compat/results.md
  phase2-deployment/results.md
  phase3-functional/results.md
  phase4-migration/results.md
  phase5-remote-store-perf/results.md
  phase6-search-perf/results.md
  phase7-scale/results.md
  phase8-multisite/results.md
```

### Check completeness at any time

Run from the **repo root**:

```bash
python results/check_results.py
```

Prints a per-phase status (COMPLETE / PARTIAL / NOT STARTED), lists every blank field, unanswered yes/no, and missing attachment, and gives a final READY TO SUBMIT / NEARLY READY / NOT READY verdict.

### Package and send results

Run from the **repo root** when ready to submit (or for a checkpoint review):

```bash
./collect_results.sh
```

This script:
- Auto-captures OS, Python, and git info → `results/00-env-info-auto.txt`
- Copies the latest Phase 1 JUnit XML and pytest log → `results/phase1-s3-compat/`
- Warns about any phases that still have unfilled fields
- Creates **`results-bundle-<YYYYMMDD-HHMMSS>.tar.gz`** in the repo root

Send that `.tar.gz` to your Splunk partner team contact.

---

## Expected Test Outcomes

Deliverables to share with Splunk:

1. **Executive summary** of test results: search performance, upload/download throughput, multi-site replication throughput (basic/functional and scale).
2. **Versions:** Splunk Enterprise and object storage used.
3. **Infrastructure:** Network topology (indexers ↔ remote storage), indexer count, local storage size/type, remote storage specs.
4. **Performance summary:** Average and peak upload/download throughput (per instance and deployment-wide); search latency at 25%, 50%, 75%, 100% cache; multi-site replication lag and throughput.
5. **Remote storage:** Configuration and deployment considerations for production.
6. **Compliance:** Confirmation of SmartStore multi-site object storage requirements; links to vendor docs (versioning, replication, multi-site).
7. **Network:** Recommended topology between indexers and remote storage at scale (e.g. 100 indexers).
8. **Scaling:** When to add storage (e.g. beyond M PB); ratio of indexers to storage nodes for target connectivity (e.g. 2.5 Gbps per indexer).
9. **Solution brief** draft.
10. **Approval:** Solution brief and any other published content must be **reviewed and approved by the Splunk partner team** before publication.

---

## Quick links

| Resource | Location |
|---------|----------|
| **S3 API compatibility tests** (Phase 1) | [s3tests/README.rst](s3tests/README.rst). All assets in **s3tests/** (script, config samples, setup, tox, requirements). |
| **Results templates** (all phases) | [results/](results/) — one `results.md` per phase; run `python results/check_results.py` to check completeness |
| **Results packaging script** | [`collect_results.sh`](collect_results.sh) — bundles all results into a `.tar.gz` |
| **Splunk SmartStore system requirements** | [docs.splunk.com](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/SmartStoresystemrequirements) |
| **Migrate to SmartStore** | [docs.splunk.com](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/MigratetoSmartStore) |
| **Multisite SmartStore** | [docs.splunk.com](https://docs.splunk.com/Documentation/Splunk/latest/Indexer/MultisiteSmartStore) |
