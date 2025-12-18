# 🖥️ OS-Tracker - System Monitor

A cross-platform system monitoring solution with Docker Hub distribution. Monitor CPU, GPU, memory, disk, and network metrics with a beautiful web dashboard.

## 🚀 For End Users (Quick Start)

**Want to just run the monitor? Use the release branch:**

```bash
git clone -b release https://github.com/momaws232/OS-Tracker.git
cd OS-Tracker
quick_start.bat
```

Open your browser to `http://localhost:8080` and you're done! 🎉

---

## 👨‍💻 For Developers

This is the **main branch** with full source code and development tools.

### Features

- **Cross-Platform Support**: Windows, Linux, and macOS
- **Comprehensive Monitoring**:
  - CPU performance and temperature
  - GPU utilization (NVIDIA, AMD, Intel)
  - Disk usage and SMART status
  - Memory consumption (RAM & Swap)
  - Network interface statistics
  - System load metrics
- **Docker Hub Distribution**: Pre-built images for easy deployment
- **Modern Web Dashboard**: Real-time charts with Plotly
- **Alert System**: Configurable thresholds with notifications
- **REST API**: Access metrics programmatically

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Docker Hub                             │
│  ┌──────────────────────┐  ┌──────────────────────┐    │
│  │ dashboard:latest     │  │ bash-monitor:latest  │    │
│  └──────────────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                          │
                          │ docker pull
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   Local Machine                          │
│  ┌──────────────────────┐  ┌──────────────────────┐    │
│  │ Dashboard Container  │  │ Windows Monitor      │    │
│  │ (from Docker Hub)    │  │ (Python Script)      │    │
│  └──────────────────────┘  └──────────────────────┘    │
│           │                          │                   │
│           └──────────┬───────────────┘                   │
│                      ▼                                   │
│              ┌──────────────┐                            │
│              │ Metrics Data │                            │
│              └──────────────┘                            │
└─────────────────────────────────────────────────────────┘
```

### Development Setup

#### Prerequisites

- **Docker Desktop**: For running containers
- **Python 3.7+**: For Windows metrics collection
- **Git**: For version control
- **Docker Hub Account**: For pushing images (free at https://hub.docker.com)

#### Clone the Repository

```bash
git clone https://github.com/momaws232/OS-Tracker.git
cd OS-Tracker
```

#### Build and Push Images to Docker Hub

```bash
# Run the push script
push_to_dockerhub.bat

# Enter your Docker Hub username and password
# Images will be built and pushed to Docker Hub
```

#### Test Locally

```bash
# Run the quick start
quick_start.bat

# Access dashboard at http://localhost:8080
```

### Project Structure

```
OS-Tracker/
├── push_to_dockerhub.bat          # Build and push images to Docker Hub
├── quick_start.bat                # Pull images and run (for testing)
├── DOCKERHUB_SETUP.md             # Docker Hub setup guide
├── QUICK_REFERENCE.md             # Quick reference guide
│
└── system-monitor/
    ├── docker/
    │   ├── Dockerfile.dashboard       # Dashboard container
    │   └── Dockerfile.bash-monitor    # Bash monitor container
    ├── reporting/
    │   ├── reporter.py                # Flask web application
    │   └── templates/
    │       └── dashboard.html         # Web dashboard UI
    ├── scripts/                       # Monitoring scripts
    ├── config/                        # Configuration files
    ├── docker-compose-solution1.yml   # Dashboard compose file
    ├── docker-compose-bash.yml        # Bash monitor compose file
    ├── monitor_windows.py             # Windows metrics collector
    ├── monitor_loop.bat               # Continuous monitoring
    └── run_solution1.bat              # Start all services
```

### Making Changes

1. **Modify Code**: Make your changes to the source files
2. **Test Locally**: Run `quick_start.bat` to test
3. **Build Images**: Run `push_to_dockerhub.bat` to build and push new images
4. **Commit**: `git add .` and `git commit -m "Your message"`
5. **Push**: `git push origin main`

### Docker Hub Images

This project uses pre-built Docker images hosted on Docker Hub:

- `loptyloop/system-monitor-dashboard:latest` - Web dashboard
- `loptyloop/system-monitor-bash:latest` - Bash monitor

See [DOCKERHUB_SETUP.md](DOCKERHUB_SETUP.md) for detailed Docker Hub setup instructions.

### Documentation

- [DOCKERHUB_SETUP.md](DOCKERHUB_SETUP.md) - Complete Docker Hub setup guide
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick reference for common tasks
- [system-monitor/README.md](system-monitor/README.md) - Detailed system monitor documentation

### API Endpoints

- `GET /api/latest` - Latest metrics
- `GET /api/historical/<hours>` - Historical data
- `GET /api/charts` - Chart data
- `GET /report/html` - HTML report
- `GET /report/markdown` - Markdown report

### Troubleshooting

See [DOCKERHUB_SETUP.md#troubleshooting](DOCKERHUB_SETUP.md#troubleshooting) for common issues and solutions.

---

## 📝 License

This project is created for educational purposes as part of the Arab Academy for Science, Technology & Maritime Transport coursework.

## 🙏 Acknowledgments

- Arab Academy for Science, Technology & Maritime Transport
- College of Computing and Information Technology
- Eng. Youssef Ahmed Mehanna & Eng. Ahmed Gamal

---

**Generated:** 2025  
**Course:** Project 12th  
**Institution:** Arab Academy for Science, Technology & Maritime Transport
