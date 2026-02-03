# S3 Performance Testing Framework

## 🎯 Purpose

This framework helps you answer critical performance questions:
- How does our S3-compatible storage compare to AWS S3?
- What performance impact can we expect for our workload?
- Which operations show the biggest performance differences?
- How does performance scale with concurrency?

## 📁 Directory Structure

```
perf-tests/
├── README.md                      # This fi7. **Customize:** Adjust parameters for your workload
8. **Schedule:** Set up regular benchmarks to track trends

## 🚀 Available Scripts & Commands

### Convenience Scripts (Recommended)

These scripts combine benchmark execution with automatic report generation:

#### Quick Test Suite (~3-5 minutes)
```bash
# Run quick benchmark + generate report for single target
./quick_run_and_report.sh aws

# Configuration:
# - 1 object size (1MiB)
# - 1 concurrency (8)
# - 5 operations (PUT, GET, DELETE, LIST, MIXED)
# - 3 iterations per test
# - 10 seconds per test
```

#### Full Benchmark Suite (~30-60 minutes)
```bash
# Run comprehensive benchmark + generate report for single target
./run_and_report.sh aws

# Run both targets and generate comparison report
./run_and_report.sh aws other

# Configuration:
# - Multiple object sizes (4KiB to 128MiB)
# - Multiple concurrency levels (1 to 128)
# - 5 operations (PUT, GET, DELETE, LIST, MIXED)
# - 3 iterations per test
# - 3 minutes per test (default)
```

### Core Scripts (Advanced Usage)

#### Benchmark Execution
```bash
# Run benchmark without automatic report generation
./warp_s3_benchmark.sh --target aws

# Run with custom duration
./warp_s3_benchmark.sh --target aws --duration 5m

# Run specific operations only
./warp_s3_benchmark.sh --target aws --operations put,get

# Run multiple targets (no comparison)
./warp_s3_benchmark.sh --target aws --target other

# Run with comparison report
./warp_s3_benchmark.sh --target aws --target other --compare --report

# Use latest existing results for comparison
./warp_s3_benchmark.sh --use-latest aws other --compare --report

# Custom test matrix
./warp_s3_benchmark.sh --target aws \
  --sizes 1MiB,16MiB \
  --concurrency 8,32 \
  --operations put,get \
  --iterations 5
```

#### Report Generation
```bash
# Generate report from existing results
source .venv/bin/activate
python report.py results/aws/20260202-174138/summary.json

# Generate comparison report from two result sets
python report.py \
  results/aws/20260202-174138/summary.json \
  results/other/20260202-180000/summary.json \
  --output comparison_report.html
```

#### Validation & Testing
```bash
# Validate setup and prerequisites
./validate_setup.sh

# Run focused test (PUT, GET, LIST only - 5 seconds each)
./focused_test.sh

# Run simple PUT test (for testing)
./simple_test.sh
```

### Common Use Cases

#### First Time Setup
```bash
# 1. Validate everything is installed
./validate_setup.sh

# 2. Configure targets
vi targets/aws.env
vi targets/other.env

# 3. Run quick test to verify
./quick_run_and_report.sh aws

# 4. Open the report
open results/aws/*/report.html
```

#### Regular Performance Monitoring
```bash
# Quick weekly check
./quick_run_and_report.sh aws

# Comprehensive monthly benchmark
./run_and_report.sh aws

# Compare two systems
./run_and_report.sh aws other
```

#### Troubleshooting
```bash
# Check prerequisites
./validate_setup.sh

# Run minimal test
./simple_test.sh

# Run focused test (faster than full suite)
./focused_test.sh

# Check logs in results directory
cat results/aws/*/raw/*.json
```

#### Custom Scenarios
```bash
# Test large file performance only
./warp_s3_benchmark.sh --target aws \
  --sizes 128MiB,512MiB \
  --operations put,get \
  --duration 10m

# Test high concurrency
./warp_s3_benchmark.sh --target aws \
  --concurrency 64,128,256 \
  --duration 5m

# Quick comparison test
./warp_s3_benchmark.sh \
  --target aws --target other \
  --sizes 1MiB \
  --concurrency 8 \
  --iterations 1 \
  --duration 30s \
  --compare --report
```

### Script Reference

| Script | Purpose | Duration | Use Case |
|--------|---------|----------|----------|
| `quick_run_and_report.sh` | Quick test + report | 3-5 min | Initial validation, quick checks |
| `run_and_report.sh` | Full benchmark + report | 30-60 min | Comprehensive testing, comparisons |
| `warp_s3_benchmark.sh` | Core benchmark engine | Variable | Advanced customization |
| `report.py` | Report generator | <1 min | Regenerate reports from existing data |
| `validate_setup.sh` | Prerequisites check | <1 min | Setup verification |
| `focused_test.sh` | Fast validation test | 15-20 sec | Quick validation |
| `simple_test.sh` | Minimal PUT test | 10 sec | Basic connectivity test |

## 📊 Additional Documentation

- **[WORKFLOWS.md](WORKFLOWS.md)** - Common usage patterns and workflows
  - Running targets separately vs together
  - Managing and preserving old results
  - Comparison report workflows
  - Regular monitoring patterns
- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[BENCHMARKING.md](BENCHMARKING.md)** - Complete reference guide
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Architecture overviewumentation
├── QUICKSTART.md                  # 5-minute getting started guide
├── WORKFLOWS.md                   # Common workflows and usage patterns
├── BENCHMARKING.md                # Comprehensive reference documentation
├── PROJECT_SUMMARY.md             # Detailed project overview
├── warp_s3_benchmark.sh           # Main benchmark orchestration script
├── report.py                      # Report generation with graphs
├── validate_setup.sh              # Setup validation utility
├── targets/                       # Configuration directory
│   ├── aws.env                    # AWS S3 configuration template
│   └── other.env                  # S3-compatible storage template
└── results/                       # Generated benchmark results (created on first run)
    ├── aws/                       # Per-target results (timestamped)
    ├── other/                     # Per-target results (timestamped)
    └── comparison_*/              # Comparison reports (timestamped)
```

## ⚡ Quick Start

### 1. Install Prerequisites

**macOS:**
```bash
# Install WARP and jq
brew install minio/stable/warp jq

# Install Python packages
pip3 install pandas matplotlib seaborn jinja2
```

**Linux (Ubuntu/Debian):**
```bash
# Install WARP
wget https://github.com/minio/warp/releases/latest/download/warp_linux_amd64 -O warp
chmod +x warp && sudo mv warp /usr/local/bin/

# Install jq and Python
sudo apt-get update && sudo apt-get install -y jq python3-pip

# Install Python packages
pip3 install pandas matplotlib seaborn jinja2
```

### 2. Validate Setup

```bash
cd perf-tests
./validate_setup.sh
```

### 3. Configure Targets

Edit configuration files with your S3 credentials:

```bash
# Configure AWS S3
vi targets/aws.env

# Configure S3-compatible storage
vi targets/other.env
```

**Important:** Create the S3 buckets before running benchmarks!

### 4. Run Benchmarks

**Single target (no comparison):**
```bash
# Run benchmarks on AWS S3 only
./warp_s3_benchmark.sh --target aws

# Run benchmarks on other target only
./warp_s3_benchmark.sh --target other --duration 1m
```

**Multiple targets with comparison:**
```bash
# Run both targets and generate comparison report
./warp_s3_benchmark.sh --target aws --target other --compare --report
```

**Note:** Each run creates a timestamped directory, so old results are automatically preserved!

### 5. Run Tests and Generate Report

**Quick test (recommended for first time):**
```bash
# Run quick benchmark suite with automatic report generation
./quick_run_and_report.sh aws
```

**Full benchmark suite:**
```bash
# Run comprehensive benchmark with report
./run_and_report.sh aws

# Run both targets and compare
./run_and_report.sh aws other
```

### 6. View Results

```bash
# Find and open the latest report
open $(find results -name "report.html" -type f | sort | tail -1)  # macOS
xdg-open $(find results -name "report.html" -type f | sort | tail -1)  # Linux
```

## 📊 What Gets Tested

### Default Test Matrix

- **Object Sizes:** 4KiB, 64KiB, 1MiB, 16MiB, 128MiB
- **Concurrency Levels:** 1, 8, 32, 128
- **Operations:** PUT, GET, DELETE, LIST, MIXED
- **Iterations:** 3 per test (median used)
- **Duration:** 3 minutes per test
- **Warmup:** 30 seconds before each test

**Default object sizes:** 4KiB, 64KiB, 1MiB, 16MiB, 128MiB, 750MiB

**Total tests:** 6 sizes × 4 concurrency × 5 operations × 3 iterations = **360 benchmarks**

### Metrics Collected

- **Throughput:** MiB/s (higher is better)
- **Operations/sec:** Request rate (higher is better)
- **Latency:**
  - Average latency
  - P50 (median)
  - P90 (90th percentile)
  - P99 (99th percentile - tail latency)
- **Error Rate:** Percentage of failed operations (lower is better)

## 📈 Output & Reports

### Structured Data

All results are saved as JSON for reproducibility:

- **`summary.json`** - Parsed metrics for each test
- **`merged_summary.json`** - Combined data from multiple targets
- **`metadata.json`** - Environment and configuration details

### Visual Reports

Automatically generated graphs:

- Throughput vs object size
- Throughput vs concurrency
- P99 latency comparisons
- Per-operation performance charts

### HTML Report

Professional report includes:

- **Executive Summary:** Overall verdict, top improvements/regressions
- **Environment Info:** Test conditions and configuration
- **Comparison Tables:** Side-by-side metrics with percentage deltas
- **Performance Charts:** Embedded graphs for visual analysis
- **Interpretation Notes:** Guidance on understanding results

## � Managing Results

### Directory Structure

Each benchmark run creates a timestamped directory:

```
results/
├── aws/
│   ├── 2024-01-26_10-00-00/     # First run
│   │   ├── raw/
│   │   ├── summary.json
│   │   └── metadata.json
│   └── 2024-01-26_14-30-00/     # Second run
│       ├── raw/
│       ├── summary.json
│       └── metadata.json
├── other/
│   ├── 2024-01-26_11-00-00/
│   └── 2024-01-26_15-00-00/
└── comparison_2024-01-26_15-30-00/    # Comparison report
    ├── merged_summary.json
    ├── charts/
    ├── report.html
    └── metadata.json
```

### Key Features

**✅ Automatic Preservation**
- Each run creates a new timestamped directory
- Old results are never overwritten
- Safe to run multiple benchmarks over time

**✅ Independent Target Runs**
- Run targets separately: `./warp_s3_benchmark.sh --target aws`
- Each target maintains its own history
- Compare anytime using `--use-latest` flag

**✅ Flexible Comparison**
- Generate comparison from any saved results
- Old comparison reports remain intact
- Create multiple comparison reports from same data

### Common Workflows

**Workflow 1: Baseline then Compare**
```bash
# Day 1: Establish AWS baseline
./warp_s3_benchmark.sh --target aws

# Day 2: Test alternative storage
./warp_s3_benchmark.sh --target other

# Day 2: Generate comparison report
./warp_s3_benchmark.sh --target aws --target other --use-latest --compare --report
```

**Workflow 2: Regular Monitoring**
```bash
# Week 1: Run AWS benchmark
./warp_s3_benchmark.sh --target aws

# Week 2: Run AWS benchmark again (old results preserved)
./warp_s3_benchmark.sh --target aws

# Week 3: Compare latest vs baseline (manually select directories if needed)
```

**Workflow 3: Update One Target**
```bash
# Update only the 'other' target, keep AWS results unchanged
./warp_s3_benchmark.sh --target other

# Generate new comparison using latest AWS + latest other
./warp_s3_benchmark.sh --target aws --target other --use-latest --compare --report

# Old comparison reports still available in results/comparison_*/
```

### Viewing Old Results

```bash
# List all benchmark runs
ls -lt results/*/

# List all comparison reports
find results -name "report.html" -type f | sort

# Open a specific old report
open results/comparison_2024-01-26_15-30-00/report.html

# Open the latest comparison report
open $(find results -name "report.html" -type f | sort | tail -1)
```

### Cleaning Up Old Results

```bash
# Delete results older than 30 days
find results -type d -name "20*" -mtime +30 -exec rm -rf {} \;

# Keep only last 5 benchmark runs per target
cd results/aws && ls -t | tail -n +6 | xargs rm -rf

# Archive old results
tar -czf benchmark-archive-$(date +%Y%m%d).tar.gz results/
```

## �🔧 Usage Examples

### Example 1: Quick Validation

Test a single target quickly:
```bash
./warp_s3_benchmark.sh --target aws --duration 1m --sizes "1MiB" --concurrency "8"
```

### Example 2: Full Comparison

Compare AWS S3 vs S3-compatible storage:
```bash
./warp_s3_benchmark.sh \
  --target aws \
  --target other \
  --compare \
  --report
```

### Example 3: Custom Workload

Test specific scenario matching your production workload:
```bash
./warp_s3_benchmark.sh \
  --target aws \
  --target minio \
  --sizes "1MiB,16MiB" \
  --concurrency "8,32,128" \
  --duration 10m \
  --iterations 5 \
  --compare \
  --report
```

### Example 4: Large Object Testing

Focus on large files (multipart uploads):
```bash
./warp_s3_benchmark.sh \
  --target aws \
  --target other \
  --sizes "128MiB,256MiB,512MiB" \
  --concurrency "8,32" \
  --duration 5m \
  --compare \
  --report
```

### Example 5: Regenerate Report

Use existing data to regenerate report:
```bash
./warp_s3_benchmark.sh \
  --target aws \
  --target other \
  --use-latest \
  --compare \
  --report
```

### Example 6: Run Single Target (Preserve Old Comparisons)

Run benchmarks on one target without affecting old comparison reports:
```bash
# Update only AWS results
./warp_s3_benchmark.sh --target aws

# Old comparison reports are preserved in results/comparison_*/
# Each run creates a new timestamped directory
```

### Example 7: Compare Old Results with New Run

Run one target, then use old and new results for comparison:
```bash
# 1. Run AWS benchmarks (creates results/aws/2024-01-26_10-00-00/)
./warp_s3_benchmark.sh --target aws

# 2. Later, run other target
./warp_s3_benchmark.sh --target other

# 3. Generate comparison from latest results of both targets
./warp_s3_benchmark.sh --target aws --target other --use-latest --compare --report
```

## 📝 Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--target <name>` | Target configuration (can repeat) | Required |
| `--duration <time>` | Duration per test (e.g., 3m, 5m) | 3m |
| `--warmup <time>` | Warmup period | 30s |
| `--sizes <list>` | Object sizes (comma-separated) | 4KiB,64KiB,1MiB,16MiB,128MiB |
| `--concurrency <list>` | Concurrency levels | 1,8,32,128 |
| `--iterations <n>` | Iterations per test | 3 |
| `--compare` | Generate comparison dataset | false |
| `--report` | Generate HTML report | false |
| `--use-latest` | Use existing results | false |
| `--skip-cleanup` | Keep temporary objects | false |
| `--verbose` | Enable verbose logging | false |

## 🧪 Test Scenarios

### Scenario 1: Migration Validation
**Goal:** Verify acceptable performance before migrating from AWS S3

```bash
./warp_s3_benchmark.sh --target aws --target new-storage --compare --report
```

**Look for:** < 25% performance degradation on critical operations

### Scenario 2: Scalability Testing
**Goal:** Understand how performance scales with load

```bash
./warp_s3_benchmark.sh \
  --target production \
  --sizes "1MiB" \
  --concurrency "1,2,4,8,16,32,64,128" \
  --report
```

**Look for:** Linear throughput scaling up to saturation point

### Scenario 3: Workload Simulation
**Goal:** Test with production-like object sizes

```bash
# Analyze your production workload first
# Then test those specific sizes
./warp_s3_benchmark.sh \
  --target aws \
  --target candidate \
  --sizes "512KiB,2MiB,8MiB" \
  --concurrency "16,32" \
  --duration 10m \
  --iterations 5 \
  --compare \
  --report
```

### Scenario 4: Regression Testing
**Goal:** Track performance changes over time

```bash
# Run regularly (e.g., weekly) with consistent parameters
./warp_s3_benchmark.sh \
  --target production \
  --duration 5m \
  --iterations 5 \
  --report

# Compare results/ directories over time
```

## 📖 Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[BENCHMARKING.md](BENCHMARKING.md)** - Complete reference guide
  - Installation instructions
  - Configuration details
  - Advanced usage
  - Results interpretation
  - Troubleshooting
  - Best practices
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Project overview and architecture

## 🔍 Interpreting Results

### Performance Deltas

- **< ±10%:** Within normal variance (not significant)
- **±10-25%:** Noticeable difference (investigate further)
- **> ±25%:** Significant difference (actionable)

### Common Patterns

1. **Larger objects → Higher throughput:** Normal (better bandwidth utilization)
2. **Higher concurrency → Higher throughput:** Expected (up to saturation)
3. **Higher concurrency → Higher P99 latency:** Normal (queuing effects)
4. **Small objects favor low-latency storage:** Network RTT is critical
5. **Large objects favor high-bandwidth storage:** Throughput is critical

### Red Flags

- **High error rates (> 1%):** Configuration or connectivity issues
- **Inconsistent results across iterations:** Network instability
- **Very high P99 latency:** Potential queuing or resource contention
- **Throughput regression > 50%:** Investigate immediately

## 💰 Cost Considerations

### AWS S3 Costs

A full benchmark run generates approximately:
- 100,000+ PUT requests
- 100,000+ GET requests
- 100,000+ DELETE requests
- Several GB data transfer (mostly within region)

**Estimated cost:** $1-5 per full run (varies by region)

### Cost Optimization

- Use cheaper regions (us-east-1 typically cheapest)
- Reduce iterations for exploratory runs (`--iterations 1`)
- Shorten duration for quick tests (`--duration 1m`)
- Focus on specific sizes/operations relevant to your workload
- Clean up objects after benchmarks (automatic by default)

## 🛠️ Troubleshooting

### Common Issues

**Issue:** `warp: command not found`  
**Fix:** Install WARP (see Quick Start section)

**Issue:** `bucket does not exist`  
**Fix:** Create buckets manually before running benchmarks
```bash
aws s3 mb s3://your-bucket-name --region us-west-2
```

**Issue:** `access denied`  
**Fix:** Verify credentials and IAM permissions (PutObject, GetObject, DeleteObject, ListBucket)

**Issue:** `connection timeout`  
**Fix:** Check endpoint URL, TLS setting, and network connectivity

**Issue:** No graphs in report  
**Fix:** Install Python packages: `pip3 install pandas matplotlib seaborn jinja2`

**Issue:** Inconsistent results  
**Fix:** Increase iterations (`--iterations 5`) and duration (`--duration 5m`)

### Debug Mode

Run with verbose logging:
```bash
./warp_s3_benchmark.sh --target aws --verbose
```

### Validation

Check your setup:
```bash
./validate_setup.sh
```

## 🎓 Best Practices

1. **Run from same region:** Test from the same region/datacenter as your storage
2. **Multiple iterations:** Use at least 3 iterations (5+ for critical decisions)
3. **Adequate duration:** 3-5 minutes minimum per test
4. **Focus on your workload:** Customize sizes/concurrency to match real usage
5. **Document results:** Save HTML reports for future reference
6. **Repeat testing:** Run at different times to account for variance
7. **Clean environment:** Ensure no other heavy I/O operations during testing
8. **Stable network:** Use reliable network connection

## 🚀 Next Steps

1. **Validate setup:** Run `./validate_setup.sh`
2. **Configure targets:** Edit `targets/*.env` files
3. **Create buckets:** Ensure S3 buckets exist
4. **Quick test:** Run with `--duration 1m` first
5. **Full benchmark:** Run complete suite with `--compare --report`
6. **Review report:** Analyze `results/comparison_*/report.html`
7. **Customize:** Adjust parameters for your workload
8. **Schedule:** Set up regular benchmarks to track trends

## � Additional Documentation

- **[WORKFLOWS.md](WORKFLOWS.md)** - Common usage patterns and workflows
  - Running targets separately vs together
  - Managing and preserving old results
  - Comparison report workflows
  - Regular monitoring patterns
- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[BENCHMARKING.md](BENCHMARKING.md)** - Complete reference guide
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Architecture overview

## �📞 Support

- **WARP Documentation:** https://github.com/minio/warp
- **AWS S3 Performance Guide:** https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html
- **MinIO Documentation:** https://min.io/docs/minio/linux/index.html

## 📄 License

This performance testing framework is part of the s3-tests project.

---

**Ready to benchmark?** Start with `./validate_setup.sh` then follow the Quick Start guide!

**Key Feature:** All benchmark runs create timestamped directories - old results are never overwritten! See [WORKFLOWS.md](WORKFLOWS.md) for details.
