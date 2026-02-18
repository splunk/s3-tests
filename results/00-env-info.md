# Environment and Deployment Information

Fill this in once before running any tests. Attach to every results submission.

---

## Partner / Contact

| Field | Value |
|-------|-------|
| Company / partner name | |
| Contact name | |
| Contact email | |
| Submission date | |

---

## Software Versions

| Component | Version |
|-----------|---------|
| Splunk Enterprise | |
| Object storage product | |
| Object storage version | |
| OS / Linux distro on indexers | |
| Python (for S3 compat tests) | |

---

## Deployment Topology

| Field | Value |
|-------|-------|
| Number of indexers | |
| Number of search heads | |
| Cluster master: site1 / site2 / standalone | |
| Multi-site (yes/no) | |
| Sites (if multi-site) | |

## Indexer Hardware (per node)

| Field | Value |
|-------|-------|
| CPU (cores / model) | |
| RAM (GB) | |
| Local storage type (SSD/HDD/NVMe) | |
| Local storage size (TB) | |
| Network bandwidth to remote storage | |

## Remote Object Storage

| Field | Value |
|-------|-------|
| Vendor / product name | |
| Deployment model (cloud / on-prem) | |
| Number of storage nodes (if applicable) | |
| Total usable capacity (TB) | |
| Network bandwidth from indexers to storage | |
| Endpoint / VIP / GSLB URL | |
| Versioning enabled (yes/no) | |
| Bi-directional replication (yes/no, multi-site only) | |

## Splunk Config (server.conf — must be same for all tests)

```ini
[general]
parallelIngestionPipelines = 2

[indexer]
tsidxWritingLevel = 4

[cachemanager]
max_cache_size = 100000
```

Confirm all three settings are in place: **yes / no**

---

## Notes / Deviations

<!-- Any differences from the test plan, environment constraints, or known issues -->
