# 🚀 System Monitor - Quick Start

**One-Click Installation for Windows**

## 📥 Installation (3 Simple Steps)

### Step 1: Download the Installer
Click the `quick_start.bat` file above and download it to your computer.

### Step 2: Run the Installer
Double-click `quick_start.bat` - it will automatically:
- ✅ Download the complete project
- ✅ Install all dependencies
- ✅ Build the Docker container
- ✅ Start the monitoring system
- ✅ Open your browser to the dashboard

### Step 3: Done! 🎉
Your system monitor is now running at **http://localhost:8080**

---

## 📋 Prerequisites

Before running `quick_start.bat`, make sure you have:

1. **Git** - [Download here](https://git-scm.com/downloads)
2. **Python 3.x** - [Download here](https://www.python.org/downloads/) *(Check "Add to PATH")*
3. **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop) *(Must be running)*

---

## ❓ What Does This Monitor?

- 📊 **CPU Usage & Temperature** - Real-time processor monitoring
- 💾 **Memory Usage** - RAM consumption tracking
- 🎮 **GPU Stats** - Graphics card monitoring (NVIDIA/AMD/Intel)
- 💿 **Disk Usage** - Storage space tracking
- 🌐 **Network Activity** - Upload/download speeds
- ⚡ **Top Processes** - See what's using your resources

---

## 🛑 How to Stop

```cmd
cd system-monitor
docker-compose -f docker-compose-solution1.yml down
```
Then close the minimized PowerShell window.

---

## 📚 For Developers

Want to contribute or customize? Switch to the **[main branch](https://github.com/Asserali/os-rep/tree/main)** for:
- Complete source code
- Development documentation
- Multi-platform support (Linux, macOS)
- Advanced configuration options

---

## 🐛 Troubleshooting

### "Git is not installed"
Download and install Git from: https://git-scm.com/downloads

### "Python is not installed"
Download and install Python from: https://www.python.org/downloads/  
⚠️ **Important:** Check "Add Python to PATH" during installation

### "Docker is not running"
1. Install Docker Desktop: https://www.docker.com/products/docker-desktop
2. Start Docker Desktop
3. Wait for the whale icon to appear in your system tray
4. Run `quick_start.bat` again

### "Port 8080 already in use"
Another application is using port 8080. Stop it or modify the port in `docker-compose-solution1.yml`

---

## 📖 Documentation

For detailed guides, see the **[main branch](https://github.com/Asserali/os-rep)**:
- Installation Guide
- User Manual
- Deployment Options
- Platform-specific Instructions

---

## 📄 License

This project is open source and available for personal and educational use.

---

## 🌟 Support

Found this useful? Star the repository! ⭐

**Enjoy monitoring your system!** 🚀
