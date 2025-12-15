#!/bin/bash
# WSL System Monitor - Accurate metrics using native Linux commands
# Run this in WSL for full Linux-style monitoring

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

output_json() {
    python3 -c "import json, sys; data = sys.stdin.read(); print(json.dumps(json.loads(data), indent=2) if data.strip() else '{}')" 2>/dev/null || cat
}

# Function to create a progress bar
progress_bar() {
    local percent=$1
    # Convert to integer, handling decimals
    local int_percent=$(echo "$percent" | awk '{printf "%d", $1}')
    local width=20
    local filled=$((int_percent * width / 100))
    local empty=$((width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "]"
}

# Function to get color based on percentage
get_color() {
    local percent=$1
    # Convert to integer for comparison
    local int_percent=$(echo "$percent" | awk '{printf "%d", $1}')
    
    if [ "$int_percent" -lt 50 ]; then
        echo -e "${GREEN}"
    elif [ "$int_percent" -lt 80 ]; then
        echo -e "${YELLOW}"
    else
        echo -e "${RED}"
    fi
}

# Function to get CPU temperature
get_cpu_temp() {
    # WSL/Docker containers typically cannot access hardware sensors directly
    # Return N/A to indicate temperature monitoring is not available in containerized environment
    echo "N/A"
    return
    
    # Method 1: Host thermal zones (Docker with mounted /host/sys)
    if [ -d "/host/sys/class/hwmon" ]; then
        # Look for CPU temperature in hwmon (k10temp for AMD, coretemp for Intel)
        for hwmon in /host/sys/class/hwmon/hwmon*/temp*_label; do
            if [ -f "$hwmon" ]; then
                label=$(cat "$hwmon" 2>/dev/null)
                if echo "$label" | grep -qi "Tctl\|Tdie\|Package\|Core 0"; then
                    temp_file="${hwmon/_label/_input}"
                    if [ -f "$temp_file" ]; then
                        temp=$(cat "$temp_file" 2>/dev/null)
                        if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                            echo "$temp" | awk '{printf "%.1f", $1/1000}'
                            return
                        fi
                    fi
                fi
            fi
        done
    fi
    
    # Method 4: sensors command (lm-sensors) - CPU specific
    if command -v sensors &> /dev/null; then
        temp=$(sensors 2>/dev/null | grep -i "Tctl:\|Tdie:\|Package id 0:" | head -1 | grep -oE '\+[0-9]+\.[0-9]+' | sed 's/+//')
        if [ -n "$temp" ]; then
            echo "$temp"
            return
        fi
    fi
    
    # Method 5: /sys/class/thermal (look for CPU-specific zones)
    for zone in /sys/class/thermal/thermal_zone*/type; do
        if [ -f "$zone" ]; then
            zone_type=$(cat "$zone" 2>/dev/null)
            if echo "$zone_type" | grep -qi "cpu\|x86\|pkg\|acpi"; then
                temp_file="${zone/type/temp}"
                if [ -f "$temp_file" ]; then
                    temp=$(cat "$temp_file" 2>/dev/null)
                    if [ -n "$temp" ] && [ "$temp" -gt 1000 ]; then
                        echo "$temp" | awk '{printf "%.1f", $1/1000}'
                        return
                    fi
                fi
            fi
        fi
    done
    
    # Method 6: ACPI thermal zone
    if [ -f "/proc/acpi/thermal_zone/THM0/temperature" ]; then
        temp=$(cat /proc/acpi/thermal_zone/THM0/temperature 2>/dev/null | awk '{print $2}')
        if [ -n "$temp" ]; then
            echo "$temp"
            return
        fi
    fi
    
    # Last resort: Show "N/A" instead of GPU temp (CPU temp should not equal GPU temp)
    echo "N/A"
}

# Clear screen
clear

# Get CPU metrics
get_cpu_metrics() {
    echo "{"
    
    # CPU usage - use mpstat if available, otherwise top
    if command -v mpstat &> /dev/null; then
        cpu_usage=$(mpstat 1 1 | awk '/Average/ {printf "%.1f", 100 - $NF}')
    else
        # Read current CPU stats from /proc/stat (more accurate for instant reading)
        read cpu_line < /proc/stat
        user=$(echo $cpu_line | awk '{print $2}')
        nice=$(echo $cpu_line | awk '{print $3}')
        system=$(echo $cpu_line | awk '{print $4}')
        idle=$(echo $cpu_line | awk '{print $5}')
        iowait=$(echo $cpu_line | awk '{print $6}')
        irq=$(echo $cpu_line | awk '{print $7}')
        softirq=$(echo $cpu_line | awk '{print $8}')
        
        total1=$((user + nice + system + idle + iowait + irq + softirq))
        idle1=$idle
        
        # Wait a moment and read again
        sleep 0.5
        
        read cpu_line < /proc/stat
        user=$(echo $cpu_line | awk '{print $2}')
        nice=$(echo $cpu_line | awk '{print $3}')
        system=$(echo $cpu_line | awk '{print $4}')
        idle=$(echo $cpu_line | awk '{print $5}')
        iowait=$(echo $cpu_line | awk '{print $6}')
        irq=$(echo $cpu_line | awk '{print $7}')
        softirq=$(echo $cpu_line | awk '{print $8}')
        
        total2=$((user + nice + system + idle + iowait + irq + softirq))
        idle2=$idle
        
        # Calculate usage
        total_diff=$((total2 - total1))
        idle_diff=$((idle2 - idle1))
        
        if [ "$total_diff" -gt 0 ]; then
            cpu_usage=$(echo "scale=1; (($total_diff - $idle_diff) * 100) / $total_diff" | bc 2>/dev/null || echo "0.0")
            # Ensure leading zero for JSON compatibility
            if [ -n "$cpu_usage" ] && [ "${cpu_usage:0:1}" = "." ]; then
                cpu_usage="0$cpu_usage"
            fi
        else
            cpu_usage="0.0"
        fi
    fi
    
    # Ensure cpu_usage is not empty
    if [ -z "$cpu_usage" ] || [ "$cpu_usage" = "" ]; then
        cpu_usage="0.0"
    fi
    
    echo "  \"usage_percent\": $cpu_usage,"
    
    # CPU name/model
    cpu_name=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
    echo "  \"name\": \"$cpu_name\","
    
    # CPU count
    cpu_count=$(nproc)
    echo "  \"count\": $cpu_count,"
    
    # Current CPU frequency (average of all cores)
    cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | awk '{sum+=$4; count+=1} END {if(count>0) printf "%.2f", sum/count; else print "0"}')
    if [ -z "$cpu_freq" ] || [ "$cpu_freq" = "0" ]; then
        # Fallback: try to get from /sys/devices/system/cpu
        cpu_freq=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{sum+=$1/1000; count+=1} END {if(count>0) printf "%.2f", sum/count; else print "0"}')
    fi
    echo "  \"frequency_mhz\": ${cpu_freq:-0},"
    
    # Maximum CPU frequency
    cpu_max_freq=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{printf "%.2f", $4}')
    echo "  \"max_frequency_mhz\": ${cpu_max_freq:-0},"
    
    # CPU Temperature
    cpu_temp=$(get_cpu_temp)
    echo "  \"temperature\": \"$cpu_temp\""
    
    echo "}"
}

# Get memory metrics
get_memory_metrics() {
    echo "{"
    
    # Parse /proc/meminfo with better precision
    total=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
    available=$(grep MemAvailable /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
    used=$(awk -v t="$total" -v a="$available" 'BEGIN {printf "%.2f", t - a}')
    percent=$(awk -v u="$used" -v t="$total" 'BEGIN {if(t>0) printf "%.1f", (u / t) * 100; else print "0"}')
    
    echo "  \"total_gb\": $total,"
    echo "  \"used_gb\": $used,"
    echo "  \"available_gb\": $available,"
    echo "  \"percent\": $percent"
    
    echo "}"
}

# Get swap metrics
get_swap_metrics() {
    echo "{"
    
    total=$(grep SwapTotal /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
    free=$(grep SwapFree /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
    used=$(awk -v t="$total" -v f="$free" 'BEGIN {printf "%.2f", t - f}')
    
    percent=$(awk -v u="$used" -v t="$total" 'BEGIN {if(t>0) printf "%.1f", (u / t) * 100; else print "0"}')
    
    echo "  \"total_gb\": $total,"
    echo "  \"used_gb\": $used,"
    echo "  \"percent\": $percent"
    
    echo "}"
}

# Get GPU metrics
get_gpu_metrics() {
    if command -v nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=gpu_name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$gpu_info" ]; then
            IFS=',' read -r name temp util mem_used mem_total <<< "$gpu_info"
            
            echo "{"
            echo "  \"available\": true,"
            echo "  \"name\": \"$(echo $name | xargs)\","
            echo "  \"temperature\": $(echo $temp | xargs),"
            echo "  \"utilization\": $(echo $util | sed 's/ %//' | xargs),"
            echo "  \"memory_used_mb\": $(echo $mem_used | sed 's/ MiB//' | xargs),"
            echo "  \"memory_total_mb\": $(echo $mem_total | sed 's/ MiB//' | xargs)"
            echo "}"
            return
        fi
    fi
    
    echo "{\"available\": false}"
}

# Get disk metrics
get_disk_metrics() {
    echo "["
    
    first=true
    # Use df -BG to force GB output and avoid M/K suffix issues
    df -BG | tail -n +2 | while read -r line; do
        device=$(echo $line | awk '{print $1}')
        total=$(echo $line | awk '{print $2}' | sed 's/G//')
        used=$(echo $line | awk '{print $3}' | sed 's/G//')
        avail=$(echo $line | awk '{print $4}' | sed 's/G//')
        percent=$(echo $line | awk '{print $5}' | sed 's/%//')
        mount=$(echo $line | awk '{print $6}')
        
        # Escape backslashes for JSON
        device=$(echo "$device" | sed 's/\\/\\\\/g')
        mount=$(echo "$mount" | sed 's/\\/\\\\/g')
        
        # Skip if values are not numbers
        if ! [[ "$total" =~ ^[0-9.]+$ ]]; then total=0; fi
        if ! [[ "$used" =~ ^[0-9.]+$ ]]; then used=0; fi
        if ! [[ "$avail" =~ ^[0-9.]+$ ]]; then avail=0; fi
        if ! [[ "$percent" =~ ^[0-9.]+$ ]]; then percent=0; fi
        
        [ "$first" = true ] || echo ","
        first=false
        
        echo "  {"
        echo "    \"device\": \"$device\","
        echo "    \"mountpoint\": \"$mount\","
        echo "    \"total_gb\": ${total:-0},"
        echo "    \"used_gb\": ${used:-0},"
        echo "    \"free_gb\": ${avail:-0},"
        echo "    \"percent\": ${percent:-0}"
        echo "  }"
    done
    
    echo "]"
}

# Get network metrics
get_network_metrics() {
    echo "{"
    
    # Total bytes sent/received
    rx_bytes=$(cat /proc/net/dev | grep -v "lo:" | tail -n +3 | awk '{sum+=$2} END {print sum/1024/1024}')
    tx_bytes=$(cat /proc/net/dev | grep -v "lo:" | tail -n +3 | awk '{sum+=$10} END {print sum/1024/1024}')
    rx_packets=$(cat /proc/net/dev | grep -v "lo:" | tail -n +3 | awk '{sum+=$3} END {print sum}')
    tx_packets=$(cat /proc/net/dev | grep -v "lo:" | tail -n +3 | awk '{sum+=$11} END {print sum}')
    
    echo "  \"bytes_sent_mb\": ${tx_bytes:-0},"
    echo "  \"bytes_recv_mb\": ${rx_bytes:-0},"
    echo "  \"packets_sent\": ${tx_packets:-0},"
    echo "  \"packets_recv\": ${rx_packets:-0}"
    
    echo "}"
}

# Get system load metrics
get_system_load_metrics() {
    echo "{"
    
    # Read load averages from /proc/loadavg
    if [ -f /proc/loadavg ]; then
        read load1 load5 load15 rest < /proc/loadavg
        echo "  \"load_average\": {"
        echo "    \"1min\": ${load1:-0},"
        echo "    \"5min\": ${load5:-0},"
        echo "    \"15min\": ${load15:-0}"
        echo "  },"
    else
        echo "  \"load_average\": {"
        echo "    \"1min\": 0,"
        echo "    \"5min\": 0,"
        echo "    \"15min\": 0"
        echo "  },"
    fi
    
    # Count processes by state
    total_processes=$(ps aux | wc -l)
    running_processes=$(ps aux | awk '$8 ~ /R/ {count++} END {print count+0}')
    sleeping_processes=$(ps aux | awk '$8 ~ /S|D|I/ {count++} END {print count+0}')
    zombie_processes=$(ps aux | awk '$8 ~ /Z/ {count++} END {print count+0}')
    
    echo "  \"total_processes\": ${total_processes:-0},"
    echo "  \"running_processes\": ${running_processes:-0},"
    echo "  \"sleeping_processes\": ${sleeping_processes:-0},"
    echo "  \"zombie_processes\": ${zombie_processes:-0},"
    
    # Get top CPU consuming processes
    echo "  \"top_cpu_processes\": ["
    ps aux --sort=-%cpu | head -6 | tail -5 | awk 'BEGIN {first=1} {
        if (!first) printf ",\n"
        first=0
        printf "    {\"name\": \"%s\", \"cpu_percent\": %.1f, \"memory_percent\": %.1f}", $11, $3, $4
    }'
    echo ""
    echo "  ],"
    
    echo "  \"timestamp\": \"$(date -Iseconds)\""
    
    echo "}"
}

# Main collection
echo -e "${BOLD}${CYAN}"
echo "================================================================"
echo "              SYSTEM MONITOR - WSL Edition                      "
echo "================================================================"
echo -e "${NC}"

# System Info
echo -e "${BOLD}${BLUE}📅 Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BOLD}${BLUE}🖥️  Hostname:${NC} $(hostname)"
echo -e "${BOLD}${BLUE}💻 Platform:${NC} Linux (WSL) $(uname -r)"
echo ""

# CPU Metrics
# Calculate CPU usage using /proc/stat for consistency with JSON output
read cpu_line < /proc/stat
user=$(echo $cpu_line | awk '{print $2}')
nice=$(echo $cpu_line | awk '{print $3}')
system=$(echo $cpu_line | awk '{print $4}')
idle=$(echo $cpu_line | awk '{print $5}')
iowait=$(echo $cpu_line | awk '{print $6}')
irq=$(echo $cpu_line | awk '{print $7}')
softirq=$(echo $cpu_line | awk '{print $8}')

total1=$((user + nice + system + idle + iowait + irq + softirq))
idle1=$idle

sleep 0.5

read cpu_line < /proc/stat
user=$(echo $cpu_line | awk '{print $2}')
nice=$(echo $cpu_line | awk '{print $3}')
system=$(echo $cpu_line | awk '{print $4}')
idle=$(echo $cpu_line | awk '{print $5}')
iowait=$(echo $cpu_line | awk '{print $6}')
irq=$(echo $cpu_line | awk '{print $7}')
softirq=$(echo $cpu_line | awk '{print $8}')

total2=$((user + nice + system + idle + iowait + irq + softirq))
idle2=$idle

total_diff=$((total2 - total1))
idle_diff=$((idle2 - idle1))

if [ "$total_diff" -gt 0 ]; then
    cpu_usage=$(echo "scale=1; (($total_diff - $idle_diff) * 100) / $total_diff" | bc 2>/dev/null || echo "0.0")
    # Ensure leading zero for JSON compatibility
    if [ -n "$cpu_usage" ] && [ "${cpu_usage:0:1}" = "." ]; then
        cpu_usage="0$cpu_usage"
    fi
else
    cpu_usage="0.0"
fi

# Ensure cpu_usage is not empty
if [ -z "$cpu_usage" ] || [ "$cpu_usage" = "" ]; then
    cpu_usage="0.0"
fi

cpu_count=$(nproc)
cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | awk '{sum+=$4; count+=1} END {if(count>0) printf "%.0f", sum/count; else print "0"}')
cpu_temp=$(get_cpu_temp)
cpu_name=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')

echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                        CPU METRICS                             ║${NC}"
echo -e "${BOLD}${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Name:        ${cpu_name:0:50}${BOLD}${GREEN}║${NC}"
cpu_color=$(get_color $cpu_usage)
echo -e "${BOLD}${GREEN}║${NC}  Usage:       ${cpu_color}$(progress_bar $cpu_usage)${NC} ${cpu_color}${cpu_usage}%${NC}$(printf '%32s' ' ')${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Cores:       ${cpu_count} cores                                          ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Frequency:   ${cpu_freq} MHz                                        ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Temperature: ${cpu_temp} C                                          ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Memory Metrics
total=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
available=$(grep MemAvailable /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
used=$(awk -v t="$total" -v a="$available" 'BEGIN {printf "%.2f", t - a}')
percent=$(awk -v u="$used" -v t="$total" 'BEGIN {if(t>0) printf "%.1f", (u / t) * 100; else print "0"}')

echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${YELLOW}║                       MEMORY METRICS                           ║${NC}"
echo -e "${BOLD}${YELLOW}╠════════════════════════════════════════════════════════════════╣${NC}"
mem_color=$(get_color $percent)
echo -e "${BOLD}${YELLOW}║${NC}  RAM Usage:   ${mem_color}$(progress_bar $percent)${NC} ${mem_color}${percent}%${NC}$(printf '%32s' ' ')${BOLD}${YELLOW}║${NC}"
echo -e "${BOLD}${YELLOW}║${NC}  Total:       ${total} GB                                         ${BOLD}${YELLOW}║${NC}"
echo -e "${BOLD}${YELLOW}║${NC}  Used:        ${used} GB                                         ${BOLD}${YELLOW}║${NC}"
echo -e "${BOLD}${YELLOW}║${NC}  Available:   ${available} GB                                         ${BOLD}${YELLOW}║${NC}"
echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Swap Metrics
swap_total=$(grep SwapTotal /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
swap_free=$(grep SwapFree /proc/meminfo | awk '{printf "%.2f", $2 / 1024 / 1024}')
swap_used=$(awk -v t="$swap_total" -v f="$swap_free" 'BEGIN {printf "%.2f", t - f}')
swap_percent=$(awk -v u="$swap_used" -v t="$swap_total" 'BEGIN {if(t>0) printf "%.1f", (u / t) * 100; else print "0"}')

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                       SWAP METRICS                             ║${NC}"
echo -e "${BOLD}${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
swap_color=$(get_color $swap_percent)
echo -e "${BOLD}${CYAN}║${NC}  Swap Usage:  ${swap_color}$(progress_bar $swap_percent)${NC} ${swap_color}${swap_percent}%${NC}$(printf '%32s' ' ')${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}║${NC}  Total:       ${swap_total} GB                                         ${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}║${NC}  Used:        ${swap_used} GB                                         ${BOLD}${CYAN}║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# GPU Metrics
if command -v nvidia-smi &> /dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=gpu_name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$gpu_info" ]; then
        IFS=',' read -r name temp util mem_used mem_total <<< "$gpu_info"
        temp=$(echo $temp | xargs)
        util=$(echo $util | sed 's/ %//' | xargs)
        
        echo -e "${BOLD}${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║                       GPU METRICS                              ║${NC}"
        echo -e "${BOLD}${RED}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BOLD}${RED}║${NC}  Name:        $(echo $name | xargs)$(printf '%*s' $((38 - ${#name})) ' ')${BOLD}${RED}║${NC}"
        gpu_color=$(get_color $util)
        echo -e "${BOLD}${RED}║${NC}  Utilization: ${gpu_color}$(progress_bar $util)${NC} ${gpu_color}${util}%${NC}$(printf '%31s' ' ')${BOLD}${RED}║${NC}"
        echo -e "${BOLD}${RED}║${NC}  Temperature: ${temp} C                                          ${BOLD}${RED}║${NC}"
        echo -e "${BOLD}${RED}║${NC}  Memory:      $(echo $mem_used | sed 's/ MiB//') MB / $(echo $mem_total | sed 's/ MiB//') MB                               ${BOLD}${RED}║${NC}"
        echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
fi

echo -e "${BOLD}${GREEN}✅ Saving metrics to data/metrics/latest.json...${NC}"
echo ""

# Save JSON data
{
echo "{"
echo "  \"timestamp\": \"$(date -Iseconds)\","

echo "  \"system\": {"
echo "    \"hostname\": \"$(hostname)\","
echo "    \"platform\": \"Linux (WSL)\","
echo "    \"version\": \"$(uname -r)\","
echo "    \"architecture\": \"$(uname -m)\""
echo "  },"

echo "  \"cpu\": $(get_cpu_metrics),"
echo "  \"memory\": $(get_memory_metrics),"
echo "  \"swap\": $(get_swap_metrics),"
echo "  \"disk\": $(get_disk_metrics),"
echo "  \"network\": $(get_network_metrics),"
echo "  \"gpu\": $(get_gpu_metrics),"
echo "  \"system_load\": $(get_system_load_metrics)"

echo "}"
} > /tmp/monitor_output.json 2>/dev/null

# Save formatted JSON (with error handling)
mkdir -p data/metrics 2>/dev/null
mkdir -p data/metrics/history 2>/dev/null

if [ -f /tmp/monitor_output.json ]; then
    # Save to latest file
    cp /tmp/monitor_output.json data/metrics/latest_wsl.json 2>/dev/null
    
    # Save to history with timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    cp /tmp/monitor_output.json "data/metrics/history/wsl_metrics_${TIMESTAMP}.json" 2>/dev/null
fi

echo -e "${BOLD}${GREEN}✅ Complete! Metrics saved to data/metrics/latest_wsl.json${NC}"