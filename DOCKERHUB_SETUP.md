# Docker Hub Setup Guide

## Overview

This guide explains how to set up and use the Docker Hub distribution for the System Monitor project. Instead of cloning from Git and building images locally, you'll pull pre-built images from Docker Hub.

## Prerequisites

1. **Docker Hub Account**: Create a free account at https://hub.docker.com/
2. **Docker Desktop**: Must be installed and running
3. **Python 3.7+**: Required for Windows metrics collection

## One-Time Setup: Push Images to Docker Hub

Before you can use the quick start script, you need to push your images to Docker Hub once.

### Step 1: Run the Push Script

```bash
push_to_dockerhub.bat
```

This script will:
1. Prompt for your Docker Hub username
2. Ask for your Docker Hub password
3. Build both dashboard and bash-monitor images
4. Push them to your Docker Hub repository
5. Save your username for future use

### Step 2: Verify Images on Docker Hub

Visit your Docker Hub profile to confirm the images were uploaded:
- `https://hub.docker.com/r/YOUR_USERNAME/system-monitor-dashboard`
- `https://hub.docker.com/r/YOUR_USERNAME/system-monitor-bash`

## Using Quick Start

Once images are pushed to Docker Hub, anyone can run the system monitor:

### Step 1: Run Quick Start

```bash
quick_start.bat
```

The script will:
1. Check if Docker is running
2. Ask for your Docker Hub username (or use saved one)
3. Pull the latest images from Docker Hub
4. Install Python dependencies
5. Start the system monitor

### Step 2: Access the Dashboard

Open your browser to: `http://localhost:8080`

## How It Works

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

### What Changed?

**Before (Git-based):**
1. Clone entire repository
2. Build Docker images locally
3. Run containers

**After (Docker Hub-based):**
1. Pull pre-built images from Docker Hub
2. Run containers

### Benefits

✅ **Faster Setup**: No need to clone repository or build images  
✅ **Smaller Download**: Only pull Docker images, not source code  
✅ **Easier Updates**: Just pull new image versions  
✅ **No Git Required**: Users don't need Git installed  
✅ **Consistent**: Everyone uses the same pre-built images  

## Updating Images

When you make changes to your project:

1. **Rebuild and Push**:
   ```bash
   push_to_dockerhub.bat
   ```

2. **Users Pull Updates**:
   ```bash
   docker pull YOUR_USERNAME/system-monitor-dashboard:latest
   docker pull YOUR_USERNAME/system-monitor-bash:latest
   ```

## File Structure

```
DkrHUB IMAGE FIX/
├── push_to_dockerhub.bat          # One-time setup: push to Docker Hub
├── quick_start.bat                # Pull images and run
├── dockerhub_username.txt         # Saved username (auto-generated)
└── system-monitor/
    ├── docker-compose-solution1.yml  # Dashboard container config
    ├── docker-compose-bash.yml       # Bash monitor container config
    ├── monitor_windows.py            # Windows metrics collector
    ├── monitor_loop.bat              # Continuous monitoring loop
    └── run_solution1.bat             # Start all services
```

## Troubleshooting

### "Failed to pull image"

**Cause**: Image doesn't exist on Docker Hub  
**Solution**: Run `push_to_dockerhub.bat` first to upload images

### "Docker is not running"

**Cause**: Docker Desktop is not started  
**Solution**: Start Docker Desktop and wait for it to fully load

### "Username cannot be empty"

**Cause**: No Docker Hub username provided  
**Solution**: Enter your Docker Hub username when prompted

### "Authentication required"

**Cause**: Private repository requires login  
**Solution**: Run `docker login` before pulling images

### Metrics not updating

**Cause**: Windows monitoring script not running  
**Solution**: Check if `monitor_loop.bat` is running in background

## Advanced Usage

### Using Different Image Versions

By default, the scripts use the `latest` tag. To use specific versions:

1. **Push with version tag**:
   ```bash
   docker tag YOUR_USERNAME/system-monitor-dashboard:latest YOUR_USERNAME/system-monitor-dashboard:v1.0
   docker push YOUR_USERNAME/system-monitor-dashboard:v1.0
   ```

2. **Modify docker-compose.yml**:
   ```yaml
   image: YOUR_USERNAME/system-monitor-dashboard:v1.0
   ```

### Making Images Public

By default, Docker Hub repositories are public. To make them private:

1. Go to Docker Hub repository settings
2. Change visibility to "Private"
3. Users will need to `docker login` before pulling

## Next Steps

1. ✅ Run `push_to_dockerhub.bat` to upload your images
2. ✅ Run `quick_start.bat` to test the setup
3. ✅ Share `quick_start.bat` with others for easy installation
4. ✅ Update images when you make changes

---

**Need Help?** Check the main [README.md](../README.md) for more information about the System Monitor project.
