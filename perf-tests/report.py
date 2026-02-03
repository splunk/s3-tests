#!/usr/bin/env python3
"""
report.py - Generate graphs and HTML report from WARP benchmark data
"""

import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any
import sys

try:
    import pandas as pd
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    import seaborn as sns
    from jinja2 import Template
except ImportError as e:
    print(f"Error: Missing required Python package: {e}", file=sys.stderr)
    print("Install with: pip3 install pandas matplotlib seaborn jinja2", file=sys.stderr)
    sys.exit(1)

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['figure.dpi'] = 100

def parse_size_to_bytes(size_str: str) -> int:
    """Convert size string (e.g., '4KiB', '128MiB') to bytes"""
    import re

    if size_str is None:
        return 0

    s = str(size_str).strip()
    if s == '':
        return 0

    # Normalize and capture number + unit (supports: 1MiB, 1MB, 1M, 1024)
    m = re.match(r"(?i)^\s*([0-9]+(?:\.[0-9]+)?)\s*([kmgt]?i?b?|)$", s)
    if not m:
        # fallback: try to parse as int
        try:
            return int(float(s))
        except Exception:
            return 0

    num = float(m.group(1))
    unit = (m.group(2) or '').lower()

    if unit in ('', 'b'):
        mult = 1
    elif unit in ('kib', 'kb', 'k'):
        mult = 1024
    elif unit in ('mib', 'mb', 'm'):
        mult = 1024 ** 2
    elif unit in ('gib', 'gb', 'g'):
        mult = 1024 ** 3
    elif unit in ('tib', 'tb', 't'):
        mult = 1024 ** 4
    else:
        mult = 1

    return int(num * mult)

def load_data(input_file: Path) -> pd.DataFrame:
    """Load and preprocess benchmark data"""
    with open(input_file) as f:
        data = json.load(f)
    if not data:
        print(f"Error: no benchmark data found in {input_file}", file=sys.stderr)
        print("Run the benchmark to produce summary.json before generating a report.", file=sys.stderr)
        sys.exit(2)

    df = pd.DataFrame(data)
    if 'object_size' not in df.columns:
        if 'objectSize' in df.columns:
            df['object_size'] = df['objectSize']
        elif 'size' in df.columns:
            df['object_size'] = df['size']
        else:
            df['object_size'] = '0'

    if 'target' not in df.columns:
        try:
            df['target'] = input_file.parent.parent.name
        except Exception:
            df['target'] = 'unknown'

    if 'operation' not in df.columns:
        if 'op' in df.columns:
            df['operation'] = df['op']
        else:
            df['operation'] = 'unknown'

    if 'concurrency' not in df.columns:
        if 'concurrent' in df.columns:
            df['concurrency'] = df['concurrent']
        else:
            df['concurrency'] = 1

    df['concurrency'] = pd.to_numeric(df['concurrency'], errors='coerce').fillna(1).astype(int)

    df['size_bytes'] = df['object_size'].apply(parse_size_to_bytes)
    df = df.sort_values('size_bytes')
    return df

def aggregate_iterations(df: pd.DataFrame) -> pd.DataFrame:
    """Aggregate multiple iterations (compute median)"""
    group_cols = ['target', 'operation', 'object_size', 'size_bytes', 'concurrency']
    
    agg_df = df.groupby(group_cols).agg({
        'throughput_mbps': 'median',
        'ops_per_sec': 'median',
        'avg_latency_ms': 'median',
        'p50_latency_ms': 'median',
        'p90_latency_ms': 'median',
        'p99_latency_ms': 'median',
        'total_operations': 'sum',
        'errors': 'sum',
        'error_rate': 'mean'
    }).reset_index()
    
    return agg_df

def generate_throughput_vs_size_charts(df: pd.DataFrame, charts_dir: Path, targets: List[str]):
    """Generate throughput vs object size charts for each operation"""
    operations = df['operation'].unique()
    
    for operation in operations:
        op_df = df[df['operation'] == operation]
        
        # Create figure with subplots for each concurrency
        concurrencies = sorted(op_df['concurrency'].unique())
        n_conc = len(concurrencies)
        
        fig, axes = plt.subplots(1, min(n_conc, 4), figsize=(16, 4), squeeze=False)
        axes = axes.flatten()
        
        for idx, conc in enumerate(concurrencies[:4]):  # Limit to 4 subplots
            ax = axes[idx]
            conc_df = op_df[op_df['concurrency'] == conc]
            
            for target in targets:
                target_df = conc_df[conc_df['target'] == target]
                # Avoid plotting rows with non-positive throughput
                target_df = target_df[target_df['throughput_mbps'].astype(float) > 0]
                if not target_df.empty:
                    ax.plot(
                        target_df['object_size'],
                        target_df['throughput_mbps'],
                        marker='o',
                        label=target,
                        linewidth=2
                    )
            
            ax.set_xlabel('Object Size')
            ax.set_ylabel('Throughput (MiB/s)')
            ax.set_title(f'Concurrency: {conc}')
            ax.legend()
            ax.grid(True, alpha=0.3)
            # Only set log scale on x-axis if there are numeric sizes present
            try:
                if (conc_df['size_bytes'].astype(float) > 0).any():
                    ax.set_xscale('log')
            except Exception:
                # Fall back to linear if any problems with data casting
                pass
        
        # Remove extra subplots
        for idx in range(n_conc, len(axes)):
            fig.delaxes(axes[idx])
        
        plt.suptitle(f'{operation.upper()} - Throughput vs Object Size', fontsize=14, y=1.02)
        plt.tight_layout()
        plt.savefig(charts_dir / f'{operation}_throughput_vs_size.png', bbox_inches='tight', dpi=150)
        plt.close()

def generate_throughput_vs_concurrency_charts(df: pd.DataFrame, charts_dir: Path, targets: List[str]):
    """Generate throughput vs concurrency charts for each operation"""
    operations = df['operation'].unique()
    
    for operation in operations:
        op_df = df[df['operation'] == operation]
        
        # Create figure with subplots for each size
        sizes = op_df.sort_values('size_bytes')['object_size'].unique()
        n_sizes = len(sizes)
        
        fig, axes = plt.subplots(1, min(n_sizes, 4), figsize=(16, 4), squeeze=False)
        axes = axes.flatten()
        
        for idx, size in enumerate(sizes[:4]):  # Limit to 4 subplots
            ax = axes[idx]
            size_df = op_df[op_df['object_size'] == size]
            
            for target in targets:
                target_df = size_df[size_df['target'] == target]
                # Avoid plotting rows with non-positive throughput
                target_df = target_df[target_df['throughput_mbps'].astype(float) > 0]
                if not target_df.empty:
                    ax.plot(
                        target_df['concurrency'],
                        target_df['throughput_mbps'],
                        marker='o',
                        label=target,
                        linewidth=2
                    )
            
            ax.set_xlabel('Concurrency')
            ax.set_ylabel('Throughput (MiB/s)')
            ax.set_title(f'Size: {size}')
            ax.legend()
            ax.grid(True, alpha=0.3)
            # Only set log scale on x-axis if concurrency values are positive
            try:
                if (size_df['concurrency'].astype(int) > 0).any():
                    ax.set_xscale('log')
            except Exception:
                pass
        
        # Remove extra subplots
        for idx in range(n_sizes, len(axes)):
            fig.delaxes(axes[idx])
        
        plt.suptitle(f'{operation.upper()} - Throughput vs Concurrency', fontsize=14, y=1.02)
        plt.tight_layout()
        plt.savefig(charts_dir / f'{operation}_throughput_vs_concurrency.png', bbox_inches='tight', dpi=150)
        plt.close()

def generate_latency_charts(df: pd.DataFrame, charts_dir: Path, targets: List[str]):
    """Generate latency percentile charts"""
    operations = df['operation'].unique()
    
    for operation in operations:
        op_df = df[df['operation'] == operation]
        
        # P99 latency vs object size for each concurrency
        fig, ax = plt.subplots(figsize=(12, 6))
        
        for target in targets:
            for conc in sorted(op_df['concurrency'].unique()):
                target_conc_df = op_df[(op_df['target'] == target) & (op_df['concurrency'] == conc)]
                # Only plot if there are positive latency values
                try:
                    has_positive_latency = (target_conc_df['p99_latency_ms'].astype(float) > 0).any()
                except Exception:
                    has_positive_latency = False

                if not target_conc_df.empty and has_positive_latency:
                    label = f'{target} (c={conc})'
                    ax.plot(
                        target_conc_df['object_size'],
                        target_conc_df['p99_latency_ms'],
                        marker='o',
                        label=label,
                        linewidth=2,
                        linestyle='--' if conc > 8 else '-'
                    )
        
        ax.set_xlabel('Object Size')
        ax.set_ylabel('P99 Latency (ms)')
        ax.set_title(f'{operation.upper()} - P99 Latency vs Object Size')
        ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        ax.grid(True, alpha=0.3)
        # Only set log scales if there are positive numeric values to plot
        try:
            if (op_df['size_bytes'].astype(float) > 0).any():
                ax.set_xscale('log')
        except Exception:
            pass

        try:
            if (op_df['p99_latency_ms'].astype(float) > 0).any():
                ax.set_yscale('log')
        except Exception:
            pass
        
        plt.tight_layout()
        plt.savefig(charts_dir / f'{operation}_p99_latency.png', bbox_inches='tight', dpi=150)
        plt.close()

def generate_comparison_tables(df: pd.DataFrame, targets: List[str]) -> Dict[str, List[Dict]]:
    """Generate comparison tables showing delta between targets"""
    if len(targets) < 2:
        return {}
    
    baseline_target = targets[0]  # First target is baseline (usually AWS)
    comparison_target = targets[1]  # Second target is comparison
    
    tables = {}
    operations = df['operation'].unique()
    
    for operation in operations:
        op_df = df[df['operation'] == operation]
        
        rows = []
        for size in op_df.sort_values('size_bytes')['object_size'].unique():
            for conc in sorted(op_df['concurrency'].unique()):
                baseline = op_df[
                    (op_df['target'] == baseline_target) &
                    (op_df['object_size'] == size) &
                    (op_df['concurrency'] == conc)
                ]
                
                comparison = op_df[
                    (op_df['target'] == comparison_target) &
                    (op_df['object_size'] == size) &
                    (op_df['concurrency'] == conc)
                ]
                
                if not baseline.empty and not comparison.empty:
                    b = baseline.iloc[0]
                    c = comparison.iloc[0]
                    
                    throughput_delta = ((c['throughput_mbps'] - b['throughput_mbps']) / b['throughput_mbps'] * 100) if b['throughput_mbps'] > 0 else 0
                    latency_delta = ((c['p99_latency_ms'] - b['p99_latency_ms']) / b['p99_latency_ms'] * 100) if b['p99_latency_ms'] > 0 else 0
                    
                    rows.append({
                        'size': size,
                        'concurrency': conc,
                        'baseline_throughput': f"{b['throughput_mbps']:.2f}",
                        'comparison_throughput': f"{c['throughput_mbps']:.2f}",
                        'throughput_delta': throughput_delta,
                        'baseline_p99': f"{b['p99_latency_ms']:.2f}",
                        'comparison_p99': f"{c['p99_latency_ms']:.2f}",
                        'latency_delta': latency_delta,
                        'baseline_errors': int(b['errors']),
                        'comparison_errors': int(c['errors'])
                    })
        
        tables[operation] = rows
    
    return tables

def calculate_summary_stats(df: pd.DataFrame, targets: List[str]) -> Dict[str, Any]:
    """Calculate executive summary statistics"""
    if len(targets) < 2:
        return {
            'baseline': targets[0] if targets else 'N/A',
            'comparison': 'N/A',
            'verdict': 'Insufficient data',
            'verdict_class': 'neutral',
            'avg_delta': 0,
            'top_improvements': [],
            'top_regressions': []
        }
    
    baseline_target = targets[0]
    comparison_target = targets[1]
    
    # Calculate deltas for all tests
    deltas = []
    
    for operation in df['operation'].unique():
        op_df = df[df['operation'] == operation]
        
        for size in op_df['object_size'].unique():
            for conc in op_df['concurrency'].unique():
                baseline = op_df[
                    (op_df['target'] == baseline_target) &
                    (op_df['object_size'] == size) &
                    (op_df['concurrency'] == conc)
                ]
                
                comparison = op_df[
                    (op_df['target'] == comparison_target) &
                    (op_df['object_size'] == size) &
                    (op_df['concurrency'] == conc)
                ]
                
                if not baseline.empty and not comparison.empty:
                    b = baseline.iloc[0]
                    c = comparison.iloc[0]
                    
                    if b['throughput_mbps'] > 0:
                        delta = ((c['throughput_mbps'] - b['throughput_mbps']) / b['throughput_mbps'] * 100)
                        deltas.append({
                            'operation': operation,
                            'size': size,
                            'concurrency': conc,
                            'delta': delta,
                            'baseline_value': b['throughput_mbps'],
                            'comparison_value': c['throughput_mbps']
                        })
    
    # Sort by delta
    deltas.sort(key=lambda x: x['delta'])
    
    # Top 3 regressions (negative delta)
    regressions = [d for d in deltas if d['delta'] < -10][:3]
    
    # Top 3 improvements (positive delta)
    improvements = [d for d in deltas if d['delta'] > 10]
    improvements.sort(key=lambda x: x['delta'], reverse=True)
    improvements = improvements[:3]
    
    # Overall verdict
    avg_delta = sum(d['delta'] for d in deltas) / len(deltas) if deltas else 0
    
    if abs(avg_delta) < 10:
        verdict = "Equivalent Performance"
        verdict_class = "success"
    elif avg_delta > 10:
        verdict = f"Faster (avg +{avg_delta:.1f}%)"
        verdict_class = "success"
    else:
        verdict = f"Slower (avg {avg_delta:.1f}%)"
        verdict_class = "danger"
    
    return {
        'baseline': baseline_target,
        'comparison': comparison_target,
        'verdict': verdict,
        'verdict_class': verdict_class,
        'avg_delta': avg_delta,
        'top_improvements': improvements,
        'top_regressions': regressions
    }

def generate_html_report(
    df: pd.DataFrame,
    charts_dir: Path,
    output_file: Path,
    targets: List[str],
    summary_stats: Dict[str, Any],
    comparison_tables: Dict[str, List[Dict]]
):
    """Generate final HTML report"""
    
    # Get metadata if available
    metadata = {}
    try:
        metadata_file = output_file.parent / 'metadata.json'
        if metadata_file.exists():
            with open(metadata_file) as f:
                metadata = json.load(f)
    except Exception:
        pass
    
    # Chart filenames
    operations = df['operation'].unique()
    charts = {}
    for op in operations:
        charts[op] = {
            'throughput_vs_size': f'charts/{op}_throughput_vs_size.png',
            'throughput_vs_concurrency': f'charts/{op}_throughput_vs_concurrency.png',
            'p99_latency': f'charts/{op}_p99_latency.png'
        }
    
    template = Template('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>S3 Benchmark Report - {{ summary_stats.comparison }} vs {{ summary_stats.baseline }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 4px solid #3498db;
            padding-bottom: 15px;
            margin-bottom: 30px;
        }
        h2 {
            color: #34495e;
            margin-top: 40px;
            margin-bottom: 20px;
            border-left: 5px solid #3498db;
            padding-left: 15px;
        }
        h3 {
            color: #555;
            margin-top: 25px;
            margin-bottom: 15px;
        }
        .executive-summary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 40px;
        }
        .verdict {
            font-size: 2em;
            font-weight: bold;
            margin-bottom: 20px;
            text-align: center;
        }
        .verdict.success { color: #2ecc71; }
        .verdict.warning { color: #f39c12; }
        .verdict.danger { color: #e74c3c; }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .stat-card {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            margin-top: 10px;
        }
        .stat-label {
            font-size: 0.9em;
            opacity: 0.9;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 0.9em;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #3498db;
            color: white;
            font-weight: bold;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .positive { color: #27ae60; font-weight: bold; }
        .negative { color: #e74c3c; font-weight: bold; }
        .neutral { color: #7f8c8d; }
        .chart-container {
            margin: 30px 0;
            text-align: center;
        }
        .chart-container img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .metadata {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 5px;
            font-size: 0.9em;
            margin: 20px 0;
        }
        .metadata dt {
            font-weight: bold;
            margin-top: 10px;
        }
        .metadata dd {
            margin-left: 20px;
            color: #555;
        }
        .toc {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .toc ul {
            list-style: none;
        }
        .toc li {
            margin: 8px 0;
        }
        .toc a {
            color: #3498db;
            text-decoration: none;
        }
        .toc a:hover {
            text-decoration: underline;
        }
        .note {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }
        .top-list {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 15px 0;
        }
        .top-list li {
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>S3 Performance Benchmark Report</h1>
        <p style="color: #7f8c8d; margin-bottom: 30px;">
            Comparison: <strong>{{ summary_stats.comparison }}</strong> vs 
            <strong>{{ summary_stats.baseline }}</strong> (baseline)
            <br>
            Generated: {{ timestamp }}
        </p>

        <div class="toc">
            <h3>Table of Contents</h3>
            <ul>
                <li><a href="#executive">Executive Summary</a></li>
                <li><a href="#environment">Test Environment</a></li>
                <li><a href="#configuration">Benchmark Configuration</a></li>
                {% for operation in operations %}
                <li><a href="#{{ operation }}">{{ operation.upper() }} Operation Results</a></li>
                {% endfor %}
                <li><a href="#interpretation">Interpretation Notes</a></li>
            </ul>
        </div>

        <div id="executive" class="executive-summary">
            <h2 style="color: white; border: none; margin-top: 0;">Executive Summary</h2>
            <div class="verdict {{ summary_stats.verdict_class }}">
                {{ summary_stats.verdict }}
            </div>
            
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-label">Baseline</div>
                    <div class="stat-value">{{ summary_stats.baseline }}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Comparison</div>
                    <div class="stat-value">{{ summary_stats.comparison }}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Avg Delta</div>
                    <div class="stat-value">{{ "%.1f"|format(summary_stats.avg_delta) }}%</div>
                </div>
            </div>

            {% if summary_stats.top_improvements %}
            <h3 style="color: white; margin-top: 30px;">Top 3 Improvements</h3>
            <ol class="top-list">
                {% for item in summary_stats.top_improvements %}
                <li>
                    <strong>{{ item.operation }}</strong> ({{ item.size }}, c={{ item.concurrency }}): 
                    <span style="color: #2ecc71;">+{{ "%.1f"|format(item.delta) }}%</span>
                    ({{ "%.2f"|format(item.comparison_value) }} vs {{ "%.2f"|format(item.baseline_value) }} MiB/s)
                </li>
                {% endfor %}
            </ol>
            {% endif %}

            {% if summary_stats.top_regressions %}
            <h3 style="color: white; margin-top: 30px;">Top 3 Regressions</h3>
            <ol class="top-list">
                {% for item in summary_stats.top_regressions %}
                <li>
                    <strong>{{ item.operation }}</strong> ({{ item.size }}, c={{ item.concurrency }}): 
                    <span style="color: #e74c3c;">{{ "%.1f"|format(item.delta) }}%</span>
                    ({{ "%.2f"|format(item.comparison_value) }} vs {{ "%.2f"|format(item.baseline_value) }} MiB/s)
                </li>
                {% endfor %}
            </ol>
            {% endif %}
        </div>

        <h2 id="environment">Test Environment</h2>
        <div class="metadata">
            <dl>
                <dt>Timestamp:</dt>
                <dd>{{ timestamp }}</dd>
                
                <dt>Hostname:</dt>
                <dd>{{ metadata.environment.hostname if metadata.environment else 'N/A' }}</dd>
                
                <dt>OS / Kernel:</dt>
                <dd>{{ metadata.environment.os if metadata.environment else 'N/A' }} / 
                    {{ metadata.environment.kernel if metadata.environment else 'N/A' }}</dd>
                
                <dt>WARP Version:</dt>
                <dd>{{ metadata.environment.warp_version if metadata.environment else 'N/A' }}</dd>
            </dl>
        </div>

        <h2 id="configuration">Benchmark Configuration</h2>
        <div class="metadata">
            <dl>
                <dt>Duration per test:</dt>
                <dd>{{ metadata.configuration.duration if metadata.configuration else 'N/A' }}</dd>
                
                <dt>Warmup period:</dt>
                <dd>{{ metadata.configuration.warmup if metadata.configuration else 'N/A' }}</dd>
                
                <dt>Object sizes:</dt>
                <dd>{{ metadata.configuration.sizes if metadata.configuration else 'N/A' }}</dd>
                
                <dt>Concurrency levels:</dt>
                <dd>{{ metadata.configuration.concurrency if metadata.configuration else 'N/A' }}</dd>
                
                <dt>Iterations per test:</dt>
                <dd>{{ metadata.configuration.iterations if metadata.configuration else 'N/A' }}</dd>
            </dl>
        </div>

        {% for operation in operations %}
        <h2 id="{{ operation }}">{{ operation.upper() }} Operation Results</h2>
        
        {% if comparison_tables.get(operation) %}
        <h3>Comparison Table</h3>
        <table>
            <thead>
                <tr>
                    <th>Size</th>
                    <th>Concurrency</th>
                    <th>{{ summary_stats.baseline }}<br>Throughput</th>
                    <th>{{ summary_stats.comparison }}<br>Throughput</th>
                    <th>Δ %</th>
                    <th>{{ summary_stats.baseline }}<br>P99 Latency</th>
                    <th>{{ summary_stats.comparison }}<br>P99 Latency</th>
                    <th>Δ %</th>
                    <th>Errors</th>
                </tr>
            </thead>
            <tbody>
                {% for row in comparison_tables[operation] %}
                <tr>
                    <td>{{ row.size }}</td>
                    <td>{{ row.concurrency }}</td>
                    <td>{{ row.baseline_throughput }} MiB/s</td>
                    <td>{{ row.comparison_throughput }} MiB/s</td>
                    <td class="{% if row.throughput_delta > 10 %}positive{% elif row.throughput_delta < -10 %}negative{% else %}neutral{% endif %}">
                        {{ "%.1f"|format(row.throughput_delta) }}%
                    </td>
                    <td>{{ row.baseline_p99 }} ms</td>
                    <td>{{ row.comparison_p99 }} ms</td>
                    <td class="{% if row.latency_delta < -10 %}positive{% elif row.latency_delta > 10 %}negative{% else %}neutral{% endif %}">
                        {{ "%.1f"|format(row.latency_delta) }}%
                    </td>
                    <td>{{ row.baseline_errors }} / {{ row.comparison_errors }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% endif %}

        {% if charts.get(operation) %}
        <h3>Performance Charts</h3>
        
        <div class="chart-container">
            <h4>Throughput vs Object Size</h4>
            <img src="{{ charts[operation].throughput_vs_size }}" alt="{{ operation }} throughput vs size">
        </div>

        <div class="chart-container">
            <h4>Throughput vs Concurrency</h4>
            <img src="{{ charts[operation].throughput_vs_concurrency }}" alt="{{ operation }} throughput vs concurrency">
        </div>

        <div class="chart-container">
            <h4>P99 Latency vs Object Size</h4>
            <img src="{{ charts[operation].p99_latency }}" alt="{{ operation }} P99 latency">
        </div>
        {% endif %}
        {% endfor %}

        <h2 id="interpretation">Interpretation Notes</h2>
        
        <div class="note">
            <h3>Key Considerations</h3>
            <ul style="margin-left: 20px; margin-top: 10px;">
                <li><strong>Latency vs Throughput:</strong> Higher concurrency typically increases throughput but may increase latency percentiles (P99).</li>
                <li><strong>Object Size Impact:</strong> Larger objects generally achieve higher throughput but may have higher absolute latency.</li>
                <li><strong>Network Factors:</strong> Results can be affected by TLS overhead, DNS resolution, network distance, and bandwidth limitations.</li>
                <li><strong>Multipart Threshold:</strong> Objects ≥128MiB typically use multipart uploads, which may show different performance characteristics.</li>
                <li><strong>Consistency:</strong> Run multiple iterations from the same client host and region for reliable comparisons.</li>
                <li><strong>Cost Consideration:</strong> AWS S3 charges for requests and data transfer; consider costs when running extensive benchmarks.</li>
            </ul>
        </div>

        <div class="note" style="background: #d1ecf1; border-left-color: #0c5460;">
            <h3>Recommendations</h3>
            <ul style="margin-left: 20px; margin-top: 10px;">
                <li>Performance deltas <strong>&lt;10%</strong> are typically within normal variance and may not be significant.</li>
                <li>Focus on the operations and object sizes most relevant to your workload.</li>
                <li>Verify results with production-like workload patterns.</li>
                <li>Consider error rates and P99 latency in addition to throughput.</li>
                <li>Repeat benchmarks at different times to account for variability.</li>
            </ul>
        </div>

        <footer style="margin-top: 50px; padding-top: 20px; border-top: 2px solid #eee; color: #7f8c8d; text-align: center;">
            <p>Generated by WARP S3 Benchmark Framework</p>
            <p style="font-size: 0.9em;">
                Raw data and logs available in: 
                <code>{{ output_dir }}</code>
            </p>
        </footer>
    </div>
</body>
</html>
    ''')
    
    html_content = template.render(
        timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC'),
        summary_stats=summary_stats,
        metadata=metadata,
        operations=sorted(df['operation'].unique()),
        comparison_tables=comparison_tables,
        charts=charts,
        targets=targets,
        output_dir=output_file.parent.name
    )
    
    with open(output_file, 'w') as f:
        f.write(html_content)

def main():
    parser = argparse.ArgumentParser(description='Generate S3 benchmark report')
    parser.add_argument('--input', required=True, help='Input JSON file with merged summary')
    parser.add_argument('--output', required=True, help='Output HTML file')
    parser.add_argument('--charts', required=True, help='Directory to save charts')
    parser.add_argument('--targets', required=True, help='Comma-separated list of targets')
    
    args = parser.parse_args()
    
    input_file = Path(args.input)
    output_file = Path(args.output)
    charts_dir = Path(args.charts)
    targets = args.targets.split(',')
    
    # Create charts directory
    charts_dir.mkdir(parents=True, exist_ok=True)
    
    # Load data
    print(f"Loading data from {input_file}...")
    df = load_data(input_file)
    
    # Aggregate iterations
    print("Aggregating iterations...")
    df_agg = aggregate_iterations(df)
    
    # Generate charts
    print("Generating charts...")
    generate_throughput_vs_size_charts(df_agg, charts_dir, targets)
    generate_throughput_vs_concurrency_charts(df_agg, charts_dir, targets)
    generate_latency_charts(df_agg, charts_dir, targets)
    
    # Generate comparison tables
    print("Generating comparison tables...")
    comparison_tables = generate_comparison_tables(df_agg, targets)
    
    # Calculate summary stats
    print("Calculating summary statistics...")
    summary_stats = calculate_summary_stats(df_agg, targets)
    
    # Generate HTML report
    print("Generating HTML report...")
    generate_html_report(df_agg, charts_dir, output_file, targets, summary_stats, comparison_tables)
    
    print(f"\nReport generated successfully: {output_file}")
    print(f"Charts saved to: {charts_dir}")

if __name__ == '__main__':
    main()
