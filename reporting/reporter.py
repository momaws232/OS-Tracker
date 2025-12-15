"""
System Monitor Reporter - Flask Application
Generates reports and serves web dashboard
"""

import os
import json
import glob
from datetime import datetime, timedelta
from pathlib import Path
from flask import Flask, render_template, jsonify, send_file, request
import plotly.graph_objs as go
import plotly.utils
import pandas as pd

app = Flask(__name__)

# Configuration
PROJECT_ROOT = os.getenv('PROJECT_ROOT', os.path.dirname(os.path.dirname(__file__)))
DATA_DIR = os.path.join(PROJECT_ROOT, 'data', 'metrics')
REPORTS_DIR = os.path.join(PROJECT_ROOT, 'data', 'reports')

# Ensure directories exist
Path(REPORTS_DIR).mkdir(parents=True, exist_ok=True)

# =================================================================
# Data Loading Functions
# =================================================================

def load_latest_metrics():
    """Load the most recent metrics data (backward compatibility - loads Windows metrics)"""
    return load_windows_metrics()

def load_windows_metrics():
    """Load Windows metrics"""
    latest_file = os.path.join(DATA_DIR, 'latest_windows.json')
    return _load_and_convert_metrics(latest_file)

def load_wsl_metrics():
    """Load WSL/Docker metrics"""
    latest_file = os.path.join(DATA_DIR, 'latest_wsl.json')
    return _load_and_convert_metrics(latest_file)

def _load_and_convert_metrics(latest_file):
    """Helper to load and convert metrics from file"""
    if os.path.exists(latest_file):
        try:
            with open(latest_file, 'r') as f:
                content = f.read().strip()
                if not content:
                    return None
                data = json.loads(content)
        except (json.JSONDecodeError, ValueError):
            return None
        
        # Check if it's Windows Python format (from monitor_windows.py)
        if 'system' in data and 'cpu' in data:
            # Convert Windows format to expected format
            converted = {
                    'system_info': {
                        'hostname': data['system']['hostname'],
                        'platform': data['system']['platform'],
                        'version': data['system'].get('version', 'Unknown'),
                        'architecture': data['system'].get('architecture', 'Unknown'),
                        'collection_time': data.get('timestamp', ''),
                        'uptime_seconds': 0
                    },
                    'cpu': {
                        'usage_percent': data['cpu']['usage_percent'],
                        'temperature_celsius': data['cpu'].get('temperature', 'N/A'),
                        'core_count': data['cpu']['count'],
                        'model': 'Unknown',
                        'frequency_ghz': data['cpu']['frequency_mhz'] / 1000
                    },
                    'memory': {
                        'total_bytes': int(data['memory']['total_gb'] * 1024**3),
                        'used_bytes': int(data['memory']['used_gb'] * 1024**3),
                        'available_bytes': int(data['memory']['available_gb'] * 1024**3),
                        'usage_percent': data['memory']['percent'],
                        'swap_total_bytes': int(data['swap']['total_gb'] * 1024**3),
                        'swap_used_bytes': int(data['swap']['used_gb'] * 1024**3),
                        'swap_usage_percent': data['swap']['percent']
                    },
                    'disk': {
                        'filesystems': [
                            {
                                'device': d['device'],
                                'mount': d['mountpoint'],
                                'total': int(d['total_gb'] * 1024**3),
                                'used': int(d['used_gb'] * 1024**3),
                                'available': int(d['free_gb'] * 1024**3),
                                'usage_percent': d['percent']
                            } for d in data.get('disk', [])
                        ],
                        'io_stats': {
                            'reads_completed': 0,
                            'writes_completed': 0,
                            'bytes_read': 0,
                            'bytes_written': 0
                        },
                        'smart_status': 'N/A'
                    },
                    'network': {
                        'interfaces': [
                            {
                                'interface': 'All',
                                'rx_bytes': int(data['network']['bytes_recv_mb'] * 1024**2),
                                'rx_packets': data['network']['packets_recv'],
                                'rx_errors': 0,
                                'tx_bytes': int(data['network']['bytes_sent_mb'] * 1024**2),
                                'tx_packets': data['network']['packets_sent'],
                                'tx_errors': 0
                            }
                        ],
                        'active_connections': 0,
                        'active_interface_names': ['All']
                    },
                    'gpu': {
                        'gpu': {
                            'vendor': 'NVIDIA' if data.get('gpu', {}).get('available') else 'None',
                            'name': data.get('gpu', {}).get('name', 'No GPU detected'),
                            'count': 1 if data.get('gpu', {}).get('available') else 0,
                            'utilization_percent': data.get('gpu', {}).get('utilization', 0),
                            'memory_used_bytes': int(data.get('gpu', {}).get('memory_used_mb', 0) * 1024**2),
                            'memory_total_bytes': int(data.get('gpu', {}).get('memory_total_mb', 1) * 1024**2),
                            'memory_percent': (data.get('gpu', {}).get('memory_used_mb', 0) / data.get('gpu', {}).get('memory_total_mb', 1) * 100) if data.get('gpu', {}).get('memory_total_mb', 0) > 0 else 0,
                            'temperature_celsius': data.get('gpu', {}).get('temperature', 0),
                            'power_watts': 0
                        },
                        'timestamp': data.get('timestamp', '')
                    },
                    'system_load': {
                        'load_average': {
                            '1min': data.get('system_load', {}).get('load_average', {}).get('1min', 0),
                            '5min': data.get('system_load', {}).get('load_average', {}).get('5min', 0),
                            '15min': data.get('system_load', {}).get('load_average', {}).get('15min', 0)
                        },
                        'total_processes': data.get('system_load', {}).get('total_processes', 0),
                        'running_processes': data.get('system_load', {}).get('running_processes', 0),
                        'sleeping_processes': data.get('system_load', {}).get('sleeping_processes', 0),
                        'zombie_processes': data.get('system_load', {}).get('zombie_processes', 0),
                        'top_cpu_processes': data.get('system_load', {}).get('top_cpu_processes', []),
                        'timestamp': data.get('timestamp', '')
                    }
                }
            return converted
        
        # Return as-is if already in correct format
        return data
    return None

def load_historical_metrics(hours=24, source='windows'):
    """Load metrics from the last N hours for specified source"""
    cutoff_time = datetime.now() - timedelta(hours=hours)
    
    # Look in history directory
    history_dir = os.path.join(DATA_DIR, 'history')
    if not os.path.exists(history_dir):
        return []
    
    # Pattern based on source
    if source == 'windows':
        pattern = 'windows_metrics_*.json'
    elif source == 'wsl':
        pattern = 'wsl_metrics_*.json'
    else:
        pattern = '*_metrics_*.json'
    
    metrics_files = glob.glob(os.path.join(history_dir, pattern))
    
    historical_data = []
    for file_path in sorted(metrics_files):
        # Extract timestamp from filename
        filename = os.path.basename(file_path)
        try:
            # Extract timestamp: windows_metrics_20251216_011410.json
            parts = filename.split('_')
            if len(parts) >= 4:
                timestamp_str = parts[2] + '_' + parts[3].replace('.json', '')
                file_time = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')
                
                if file_time >= cutoff_time:
                    data = _load_and_convert_metrics(file_path)
                    if data:
                        historical_data.append(data)
        except Exception as e:
            continue
    
    return historical_data

# =================================================================
# Chart Generation Functions
# =================================================================

def generate_cpu_chart(historical_data):
    """Generate CPU usage chart"""
    timestamps = []
    cpu_usage = []
    
    for data in historical_data:
        timestamps.append(data['system_info']['collection_time'])
        cpu_usage.append(float(data['cpu']['usage_percent']))
    
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=timestamps,
        y=cpu_usage,
        mode='lines+markers',
        name='CPU Usage',
        line=dict(color='#3498db', width=2)
    ))
    
    fig.update_layout(
        title='CPU Usage Over Time',
        xaxis_title='Time',
        yaxis_title='Usage (%)',
        yaxis=dict(range=[0, 100]),
        template='plotly_white'
    )
    
    return json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)

def generate_memory_chart(historical_data):
    """Generate memory usage chart"""
    timestamps = []
    mem_usage = []
    swap_usage = []
    
    for data in historical_data:
        timestamps.append(data['system_info']['collection_time'])
        mem_usage.append(float(data['memory']['usage_percent']))
        swap_usage.append(float(data['memory']['swap_usage_percent']))
    
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=timestamps,
        y=mem_usage,
        mode='lines+markers',
        name='Memory Usage',
        line=dict(color='#e74c3c', width=2)
    ))
    fig.add_trace(go.Scatter(
        x=timestamps,
        y=swap_usage,
        mode='lines+markers',
        name='Swap Usage',
        line=dict(color='#f39c12', width=2)
    ))
    
    fig.update_layout(
        title='Memory Usage Over Time',
        xaxis_title='Time',
        yaxis_title='Usage (%)',
        yaxis=dict(range=[0, 100]),
        template='plotly_white'
    )
    
    return json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)

def generate_disk_chart(latest_data):
    """Generate disk usage chart"""
    filesystems = latest_data['disk']['filesystems']
    
    mounts = [fs['mount'] for fs in filesystems]
    usage = [float(fs['usage_percent']) for fs in filesystems]
    
    colors = ['#2ecc71' if u < 70 else '#f39c12' if u < 90 else '#e74c3c' for u in usage]
    
    fig = go.Figure()
    fig.add_trace(go.Bar(
        x=mounts,
        y=usage,
        marker_color=colors,
        text=[f'{u:.1f}%' for u in usage],
        textposition='outside'
    ))
    
    fig.update_layout(
        title='Disk Usage by Filesystem',
        xaxis_title='Mount Point',
        yaxis_title='Usage (%)',
        yaxis=dict(range=[0, 100]),
        template='plotly_white'
    )
    
    return json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)

def generate_network_chart(historical_data):
    """Generate network traffic chart"""
    timestamps = []
    total_rx = []
    total_tx = []
    
    for data in historical_data:
        timestamps.append(data['system_info']['collection_time'])
        
        interfaces = data['network']['interfaces']
        rx = sum(int(iface['rx_bytes']) for iface in interfaces) / (1024**2)  # Convert to MB
        tx = sum(int(iface['tx_bytes']) for iface in interfaces) / (1024**2)
        
        total_rx.append(rx)
        total_tx.append(tx)
    
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=timestamps,
        y=total_rx,
        mode='lines',
        name='Received',
        fill='tozeroy',
        line=dict(color='#3498db')
    ))
    fig.add_trace(go.Scatter(
        x=timestamps,
        y=total_tx,
        mode='lines',
        name='Transmitted',
        fill='tozeroy',
        line=dict(color='#e74c3c')
    ))
    
    fig.update_layout(
        title='Network Traffic',
        xaxis_title='Time',
        yaxis_title='Data (MB)',
        template='plotly_white'
    )
    
    return json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)

# =================================================================
# Flask Routes
# =================================================================

@app.route('/')
def index():
    """Main dashboard page"""
    windows_metrics = load_windows_metrics()
    wsl_metrics = load_wsl_metrics()
    
    if not windows_metrics and not wsl_metrics:
        return '<h1>No metrics data available</h1><p>Please run the monitor first: <code>python monitor_windows.py</code> or start Docker monitor</p>', 503
    
    return render_template('dashboard.html', 
                         windows_metrics=windows_metrics, 
                         wsl_metrics=wsl_metrics,
                         metrics=windows_metrics or wsl_metrics)  # For backward compatibility

@app.route('/api/latest')
def api_latest():
    """API endpoint for latest metrics"""
    latest = load_latest_metrics()
    if latest:
        return jsonify(latest)
    return jsonify({'error': 'No data available'}), 404

@app.route('/api/historical/<int:hours>')
def api_historical(hours):
    """API endpoint for historical metrics"""
    source = request.args.get('source', 'windows')
    data = load_historical_metrics(hours, source)
    return jsonify(data)

@app.route('/api/charts')
def api_charts():
    """API endpoint for chart data"""
    source = request.args.get('source', 'windows')
    latest = load_windows_metrics() if source == 'windows' else load_wsl_metrics()
    historical = load_historical_metrics(24, source)
    
    if not latest or not historical:
        return jsonify({'error': 'Insufficient data'}), 404
    
    charts = {
        'cpu': generate_cpu_chart(historical),
        'memory': generate_memory_chart(historical),
        'disk': generate_disk_chart(latest),
        'network': generate_network_chart(historical)
    }
    
    return jsonify(charts)

@app.route('/report/html')
def report_html():
    """Generate and serve HTML report"""
    source = request.args.get('source', 'windows')
    latest = load_windows_metrics() if source == 'windows' else load_wsl_metrics()
    historical = load_historical_metrics(24, source)
    
    if not latest:
        return 'No data available', 404
    
    return render_template('report.html', latest=latest, historical=historical)

@app.route('/report/markdown')
def report_markdown():
    """Generate and serve Markdown report"""
    source = request.args.get('source', 'windows')
    latest = load_windows_metrics() if source == 'windows' else load_wsl_metrics()
    
    if not latest:
        return 'No data available', 404
    
    # Generate markdown
    md_content = generate_markdown_report(latest, source)
    
    # Save to file
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_file = os.path.join(REPORTS_DIR, f'report_{source}_{timestamp}.md')
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(md_content)
    
    return send_file(report_file, as_attachment=True, download_name=f'system_report_{source}.md')

# =================================================================
# Report Generation
# =================================================================

def generate_markdown_report(metrics, source='windows'):
    """Generate markdown report from metrics"""
    report = f"""# System Monitoring Report ({source.upper()})

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Hostname:** {metrics['system_info']['hostname']}  
**Platform:** {metrics['system_info']['platform']}

## System Overview

- **Architecture:** {metrics['system_info']['architecture']}
- **CPU Cores:** {metrics['cpu']['core_count']}
- **CPU Frequency:** {metrics['cpu']['frequency_ghz']:.2f} GHz

## Current Metrics

### CPU
- **Usage:** {metrics['cpu']['usage_percent']:.1f}%
- **Temperature:** {metrics['cpu']['temperature_celsius']}°C
- **Frequency:** {metrics['cpu']['frequency_ghz']:.2f} GHz

### Memory
- **Total:** {format_bytes(metrics['memory']['total_bytes'])}
- **Used:** {format_bytes(metrics['memory']['used_bytes'])} ({metrics['memory']['usage_percent']:.1f}%)
- **Available:** {format_bytes(metrics['memory']['available_bytes'])}
- **Swap Used:** {format_bytes(metrics['memory']['swap_used_bytes'])} ({metrics['memory']['swap_usage_percent']:.1f}%)

### Disk
"""
    
    for fs in metrics['disk']['filesystems']:
        report += f"""
#### {fs['mount']}
- **Device:** {fs['device']}
- **Total:** {format_bytes(fs['total'])}
- **Used:** {format_bytes(fs['used'])} ({fs['usage_percent']:.2f}%)
- **Available:** {format_bytes(fs['available'])}
"""
    
    report += f"""
### Network
"""
    
    for iface in metrics['network']['interfaces']:
        report += f"""#### {iface['interface']}
- **RX:** {format_bytes(iface['rx_bytes'])} ({iface['rx_packets']} packets, {iface['rx_errors']} errors)
- **TX:** {format_bytes(iface['tx_bytes'])} ({iface['tx_packets']} packets, {iface['tx_errors']} errors)

"""
    
    report += f"""
### System Load
- **1 min:** {metrics['system_load']['load_average']['1min']:.2f}
- **5 min:** {metrics['system_load']['load_average']['5min']:.2f}
- **15 min:** {metrics['system_load']['load_average']['15min']:.2f}
- **Total Processes:** {metrics['system_load']['total_processes']}
- **Running:** {metrics['system_load']['running_processes']}
- **Sleeping:** {metrics['system_load']['sleeping_processes']}

### GPU
- **Vendor:** {metrics['gpu']['gpu']['vendor']}
- **Name:** {metrics['gpu']['gpu']['name']}
- **Utilization:** {metrics['gpu']['gpu']['utilization_percent']:.1f}%
- **Temperature:** {metrics['gpu']['gpu']['temperature_celsius']}°C
- **Memory:** {format_bytes(metrics['gpu']['gpu']['memory_used_bytes'])} / {format_bytes(metrics['gpu']['gpu']['memory_total_bytes'])}

---

*Report generated by System Monitor Dashboard*  
*Timestamp: {metrics['system_info']['collection_time']}*
"""
    
    return report

def format_bytes(bytes_val):
    """Format bytes to human readable"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_val < 1024:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024
    return f"{bytes_val:.2f} PB"

def format_uptime(seconds):
    """Format uptime in human readable format"""
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    return f"{days}d {hours}h {minutes}m"

# =================================================================
# Main Entry Point
# =================================================================

@app.route('/health')
def health():
    """Health check endpoint for container"""
    return jsonify({"status": "healthy", "service": "system-monitor-dashboard"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
    app.run(host='0.0.0.0', port=8080, debug=False)
