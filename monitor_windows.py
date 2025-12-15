"""
Simple System Monitor Test - Windows Compatible
Works on Windows without Bash or complex dependencies
"""

import platform
import psutil
import json
import subprocess
from datetime import datetime

def get_cpu_temperature():
    """Get CPU temperature from LibreHardwareMonitor WMI"""
    try:
        result = subprocess.run(
            ['python', 'get_cpu_temp.py'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            temp = float(result.stdout.strip().split('\n')[-1])
            return round(temp, 1)
    except:
        pass
    return None

def get_system_metrics():
    """Collect basic system metrics on Windows"""
    
    # CPU metrics - use 1 second interval for accuracy (like Task Manager)
    cpu_percent = psutil.cpu_percent(interval=1, percpu=False)
    cpu_per_core = psutil.cpu_percent(interval=0, percpu=True)
    cpu_count = psutil.cpu_count()
    cpu_freq = psutil.cpu_freq()
    
    # Memory metrics
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()
    
    # Disk metrics
    disk_usage = []
    for partition in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(partition.mountpoint)
            disk_usage.append({
                'device': partition.device,
                'mountpoint': partition.mountpoint,
                'total_gb': round(usage.total / (1024**3), 2),
                'used_gb': round(usage.used / (1024**3), 2),
                'free_gb': round(usage.free / (1024**3), 2),
                'percent': usage.percent
            })
        except:
            continue
    
    # Network metrics
    net_io = psutil.net_io_counters()
    
    # GPU metrics
    gpu_info = get_gpu_info()
    
    # CPU temperature
    cpu_temp = get_cpu_temperature()
    
    # Process and system load metrics
    processes = list(psutil.process_iter(['status', 'cpu_percent', 'memory_percent', 'name']))
    total_processes = len(processes)
    running_processes = len([p for p in processes if p.info['status'] == 'running'])
    sleeping_processes = len([p for p in processes if p.info['status'] == 'sleeping'])
    
    # Get top CPU processes
    try:
        top_cpu_procs = sorted(
            [p for p in processes if p.info['cpu_percent'] is not None],
            key=lambda x: x.info['cpu_percent'] or 0,
            reverse=True
        )[:5]
        top_cpu_list = [
            {
                'name': p.info['name'],
                'cpu_percent': p.info['cpu_percent'] or 0,
                'memory_percent': p.info['memory_percent'] or 0
            }
            for p in top_cpu_procs
        ]
    except:
        top_cpu_list = []
    
    # Calculate load average equivalent for Windows (CPU usage over cores)
    load_1min = cpu_percent / 100 * cpu_count
    
    # System info
    metrics = {
        'timestamp': datetime.now().isoformat(),
        'system': {
            'hostname': platform.node(),
            'platform': platform.system(),
            'version': platform.version(),
            'architecture': platform.machine()
        },
        'cpu': {
            'usage_percent': cpu_percent,
            'count': cpu_count,
            'frequency_mhz': cpu_freq.current if cpu_freq else 0,
            'temperature': cpu_temp
        },
        'memory': {
            'total_gb': round(memory.total / (1024**3), 2),
            'used_gb': round(memory.used / (1024**3), 2),
            'available_gb': round(memory.available / (1024**3), 2),
            'percent': memory.percent
        },
        'swap': {
            'total_gb': round(swap.total / (1024**3), 2),
            'used_gb': round(swap.used / (1024**3), 2),
            'percent': swap.percent
        },
        'disk': disk_usage,
        'network': {
            'bytes_sent_mb': round(net_io.bytes_sent / (1024**2), 2),
            'bytes_recv_mb': round(net_io.bytes_recv / (1024**2), 2),
            'packets_sent': net_io.packets_sent,
            'packets_recv': net_io.packets_recv
        },
        'gpu': gpu_info,
        'system_load': {
            'load_average': {
                '1min': round(load_1min, 2),
                '5min': round(load_1min, 2),  # Windows doesn't have historical load
                '15min': round(load_1min, 2)
            },
            'total_processes': total_processes,
            'running_processes': running_processes,
            'sleeping_processes': sleeping_processes,
            'zombie_processes': 0,
            'top_cpu_processes': top_cpu_list,
            'timestamp': datetime.now().isoformat()
        }
    }
    
    return metrics

def get_gpu_info():
    """Get GPU information if available"""
    try:
        import subprocess
        
        # Try nvidia-smi for NVIDIA GPUs
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=gpu_name,temperature.gpu,utilization.gpu,memory.used,memory.total', 
             '--format=csv,noheader'], 
            capture_output=True, text=True, timeout=3
        )
        
        if result.returncode == 0 and result.stdout.strip():
            output = result.stdout.strip()
            parts = [p.strip() for p in output.split(',')]
            
            if len(parts) >= 5:
                gpu_name = parts[0]
                temp = float(parts[1]) if parts[1].replace('.','').isdigit() else 0
                util = float(parts[2].replace('%','').strip()) if '%' in parts[2] else float(parts[2])
                mem_used = float(parts[3].split()[0]) if parts[3] else 0
                mem_total = float(parts[4].split()[0]) if parts[4] else 1
                
                return {
                    'available': True,
                    'name': gpu_name,
                    'temperature': temp,
                    'utilization': util,
                    'memory_used_mb': mem_used,
                    'memory_total_mb': mem_total
                }
    except:
        pass
    
    return {
        'available': False,
        'name': 'No GPU detected',
        'temperature': 0,
        'utilization': 0,
        'memory_used_mb': 0,
        'memory_total_mb': 0
    }

def print_metrics(metrics):
    """Print metrics in a readable format"""
    print("=" * 60)
    print("SYSTEM MONITOR - Windows Edition")
    print("=" * 60)
    print(f"\n📅 Timestamp: {metrics['timestamp']}")
    print(f"🖥️  Hostname: {metrics['system']['hostname']}")
    print(f"💻 Platform: {metrics['system']['platform']}")
    
    print(f"\n🔥 CPU:")
    print(f"   Usage: {metrics['cpu']['usage_percent']}%")
    print(f"   Cores: {metrics['cpu']['count']}")
    print(f"   Frequency: {metrics['cpu']['frequency_mhz']:.0f} MHz")
    if metrics['cpu'].get('temperature'):
        print(f"   Temperature: {metrics['cpu']['temperature']}°C")
    
    print(f"\n💾 Memory:")
    print(f"   Total: {metrics['memory']['total_gb']} GB")
    print(f"   Used: {metrics['memory']['used_gb']} GB ({metrics['memory']['percent']}%)")
    print(f"   Available: {metrics['memory']['available_gb']} GB")
    
    if metrics['swap']['total_gb'] > 0:
        print(f"\n💿 Swap:")
        print(f"   Total: {metrics['swap']['total_gb']} GB")
        print(f"   Used: {metrics['swap']['used_gb']} GB ({metrics['swap']['percent']}%)")
    
    print(f"\n📀 Disk Usage:")
    for disk in metrics['disk']:
        print(f"   {disk['mountpoint']} ({disk['device']}):")
        print(f"      Total: {disk['total_gb']} GB")
        print(f"      Used: {disk['used_gb']} GB ({disk['percent']}%)")
        print(f"      Free: {disk['free_gb']} GB")
    
    print(f"\n🌐 Network:")
    print(f"   Sent: {metrics['network']['bytes_sent_mb']} MB ({metrics['network']['packets_sent']} packets)")
    print(f"   Received: {metrics['network']['bytes_recv_mb']} MB ({metrics['network']['packets_recv']} packets)")
    
    if metrics.get('gpu', {}).get('available', False):
        gpu = metrics['gpu']
        print(f"\n🎮 GPU:")
        print(f"   Name: {gpu['name']}")
        print(f"   Utilization: {gpu['utilization']}%")
        print(f"   Temperature: {gpu['temperature']}°C")
        print(f"   Memory: {gpu['memory_used_mb']:.0f} MB / {gpu['memory_total_mb']:.0f} MB")
    
    if metrics.get('system_load'):
        load = metrics['system_load']
        print(f"\n📊 System Load:")
        print(f"   Load Average: {load['load_average']['1min']} (1min)")
        print(f"   Total Processes: {load['total_processes']}")
        print(f"   Running: {load['running_processes']} | Sleeping: {load['sleeping_processes']}")
        if load['top_cpu_processes']:
            print(f"   Top CPU Processes:")
            for proc in load['top_cpu_processes'][:3]:
                print(f"      - {proc['name']}: {proc['cpu_percent']}%")
    
    print("\n" + "=" * 60)

def save_metrics(metrics, filename='data/metrics/latest_windows.json'):
    """Save metrics to JSON file and history"""
    import os
    from datetime import datetime
    
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    # Save latest metrics
    with open(filename, 'w') as f:
        json.dump(metrics, f, indent=2)
    
    # Also save to latest.json for backward compatibility
    with open('data/metrics/latest.json', 'w') as f:
        json.dump(metrics, f, indent=2)
    
    # Save to history with timestamp
    history_dir = 'data/metrics/history'
    os.makedirs(history_dir, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    history_file = os.path.join(history_dir, f'windows_metrics_{timestamp}.json')
    with open(history_file, 'w') as f:
        json.dump(metrics, f, indent=2)
    
    print(f"\n✅ Metrics saved to: {filename}")

if __name__ == '__main__':
    import sys
    
    # Check for silent mode (no console output)
    silent_mode = '--silent' in sys.argv or '-s' in sys.argv
    
    try:
        # Collect metrics
        metrics = get_system_metrics()
        
        # Display metrics (only if not in silent mode)
        if not silent_mode:
            print_metrics(metrics)
        
        # Save to file
        save_metrics(metrics)
        
        # Also save as JSON for viewing (only if not in silent mode)
        if not silent_mode:
            print("\nJSON Output:")
            print(json.dumps(metrics, indent=2))
        
    except Exception as e:
        if not silent_mode:
            print(f"❌ Error: {e}")
            import traceback
            traceback.print_exc()
        else:
            # In silent mode, just write error to file
            import traceback
            with open('data/logs/monitor_error.log', 'a', encoding='utf-8') as f:
                f.write(f"\n[{metrics.get('timestamp', 'unknown')}] Error: {e}\n")
                f.write(traceback.format_exc())
