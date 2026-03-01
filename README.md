<p align="center">
  <img src="https://i.imgur.com/E5hRYna.jpeg" alt="WebDroid Banner Image" width="800">
</p>

# WebDroid v3.0 - Cross-Platform Android Remote Control

Control your Android device from any platform (Windows, Mac, Linux, or any device with a browser) without root access...

# WebDroid

A persistent web server setup script for Termux on Android. No root required.

## 📋 Overview

This script automates the installation and configuration of a persistent Apache web server on Android devices using Termux. It includes watchdog services, auto-start capabilities, and monitoring tools to ensure 24/7 operation.

## ✨ Features

- **Persistent Operation** - Watchdog service ensures server runs 24/7
- **Auto-Start** - Boot scripts and Termux-services integration
- **Complete LAMP Stack** - Apache, PHP 8.3, MariaDB
- **Remote Management** - SSH access and service control commands
- **Monitoring** - Resource usage tracking and logs
- **Security** - Password-protected admin access
- **No Root Required** - Runs entirely in Termux environment

## 🚀 Quick Start

1. **Install Termux** from F-Droid or GitHub
2. **Run the setup script**:
```bash
curl -sSL https://raw.githubusercontent.com/SleepTheGod/WebDroid/main/main.sh | bash
```

Or clone and run manually:
```bash
git clone https://github.com/SleepTheGod/WebDroid
cd WebDroid
chmod +x main.sh
./main.sh
```

## 📦 What Gets Installed

- **Apache** - Web server with PHP support
- **PHP 8.3** - Latest PHP version
- **MariaDB** - Database server
- **Termux-services** - Service management
- **Watchdog** - Auto-restart on crash
- **Boot scripts** - Start on device boot
- **Monitoring tools** - htop, nload, etc.

## 🛠️ Usage

After installation, manage your server with:

```bash
# Start the server service
webserver-service start

# Check status
webserver-service status

# View logs
webserver-service logs

# Stop the server
webserver-service stop

# Restart
webserver-service restart
```

## 🌐 Accessing Your Server

- **Local URL**: `http://localhost:8080`
- **Network URL**: `http://<device-ip>:8080`
- **Web root**: `~/webserver/html/`
- **Admin credentials**: Saved in `~/webserver/password.enc`

## 📁 Directory Structure

```
~/webserver/
├── html/          # Web files (document root)
├── logs/          # Access and error logs
├── backup/        # Automated backups
├── ssl/           # SSL certificates
├── cgi-bin/       # CGI scripts
└── status/        # Server status pages
```

## 🔧 Advanced Configuration

### Custom Port
Edit the `SERVER_PORT` variable in the script before running.

### Custom Admin Password
Set before running:
```bash
export PASSWORD="your-secure-password"
```

### Auto-Start on Boot
The script installs boot scripts automatically. For Termux:Boot app support, scripts are placed in `~/.termux/boot/`.

## 📊 Monitoring

- **Watchdog logs**: `~/webserver/logs/watchdog.log`
- **Access logs**: `~/webserver/logs/access_log`
- **Error logs**: `~/webserver/logs/error_log`
- **Boot logs**: `~/webserver/logs/boot.log`

## 🔐 Security Notes

- Admin password is generated randomly and saved encrypted
- Basic authentication is configured via `.htpasswd`
- Consider changing passwords regularly
- Use SSL for production (certificates can be placed in `ssl/`)

## 📱 Requirements

- Android 7.0+
- Termux app installed
- ~500MB free storage
- Internet connection for package download

## 🐛 Troubleshooting

### Server won't start
```bash
# Check if port is already in use
netstat -tlnp | grep 8080

# View error logs
tail -f ~/webserver/logs/error_log
```

### Can't access from network
```bash
# Check IP address
ip addr show

# Verify Apache is listening on all interfaces
grep Listen $PREFIX/etc/apache2/httpd.conf
```

### Permission issues
```bash
# Run storage permission setup
termux-setup-storage
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 👤 Author

**Taylor Christian Newsome** (ClumsyLulz)
- Email: SleepRaps@gmail.com
- GitHub: [@SleepTheGod](https://github.com/SleepTheGod)

## 🙏 Acknowledgments

- Termux community
- Apache Software Foundation
- PHP Development Team

## 📚 Additional Resources

- [Termux Wiki](https://wiki.termux.com)
- [Apache Documentation](https://httpd.apache.org/docs/)
- [PHP Manual](https://www.php.net/manual/)

---

**Made with ❤️ for the Termux community**


# Part 2 For remote.sh

```markdown
# WebDroid v3.0 - Cross-Platform Android Remote Control

Control your Android device from any platform (Windows, Mac, Linux, or any device with a browser) without root access. Transform your Android device into a 24/7 accessible web server with remote control capabilities.

[![Version](https://img.shields.io/badge/version-3.0-blue.svg)](https://github.com/SleepTheGod/WebDroid)
[![Platform](https://img.shields.io/badge/platform-Android-brightgreen.svg)](https://termux.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 📋 Overview

WebDroid turns your Android device into a powerful, persistent web server with remote control capabilities. Access and control your device from anywhere on your network using a web browser, REST API, or WebSocket connections.

### ✨ Key Features

- **🌐 Cross-Platform Control** - Access from Windows, Mac, Linux, or any device with a browser
- **🚀 24/7 Operation** - Watchdog service ensures server never stops
- **📱 Remote File Manager** - Upload, download, and edit files
- **💻 Web Terminal** - Execute commands remotely
- **🔌 REST API** - Programmatic access for automation
- **📊 Real-time Monitoring** - Live system metrics and logs
- **🔄 Auto-Recovery** - Self-healing on crashes
- **🔒 Secure Access** - JWT authentication and HTTPS ready
- **⚡ No Root Required** - Runs entirely in Termux
- **📦 Multiple Clients** - Python, Node.js, and shell scripts included

## 🚀 Quick Start

1. **Install Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) or [GitHub](https://github.com/termux/termux-app/releases)

2. **Run the installation script**:
```bash
curl -sSL https://raw.githubusercontent.com/SleepTheGod/WebDroid/main/main.sh | bash
```

Or clone and run manually:
```bash
git clone https://github.com/SleepTheGod/WebDroid
cd WebDroid
chmod +x main.sh
./main.sh
```

3. **Follow the prompts**:
   - Choose your web port (default: 8080)
   - Set admin password (or let it generate randomly)
   - Wait for installation to complete

4. **Connect from any device**:
   - Note the IP address shown after installation
   - Open `http://[device-ip]:8080/remote.html` in any browser
   - Login with your admin credentials

## 📦 What's Included

### Core Services
- **Apache Web Server** - Host websites and applications
- **Node.js API Server** - REST API on port 8081
- **WebSocket Server** - Real-time updates on port 8082
- **Watchdog Service** - Auto-restart on crashes
- **Keep-Alive Service** - Prevents device sleep
- **Boot Scripts** - Auto-start on device boot

### Remote Control Features
- **Web Interface** - Full control from any browser
- **File Manager** - Browse, edit, upload/download files
- **Terminal Access** - Execute commands remotely
- **System Monitor** - Real-time CPU, memory, disk usage
- **Log Viewer** - Access all server logs
- **Service Control** - Start/stop/restart services

### Client Scripts (in `~/webserver/client/`)
- `connect.bat` - Windows batch file
- `connect.sh` - Linux/Mac shell script
- `webdroid_client.py` - Python client with full API
- `webdroid.js` - Node.js interactive shell
- `README.md` - Client documentation

## 🎮 Usage

### On Android Device

```bash
# Check server status
webserver status

# Open remote control interface
webserver remote

# View all logs
webserver logs

# Control API server
webserver api status
webserver api restart
webserver api logs

# Show client connection info
webserver client

# Recover from crashes
webserver recover

# Battery optimization help
webserver battery

# Get server information
webserver info
```

### From Any Device (Browser)

1. Open `http://[android-ip]:8080/remote.html`
2. Login with admin credentials
3. Use the dashboard to:
   - Monitor system status
   - Control services
   - Browse files
   - Execute commands
   - View logs

### Using Python Client

```python
from webdroid_client import WebDroidClient

client = WebDroidClient('192.168.1.100')
client.authenticate('your-password')

# Check status
status = client.get_status()

# List files
files = client.list_files('/html')

# Execute command
result = client.execute_command('uptime')
```

### Using Node.js Client

```bash
cd ~/webserver/client
node webdroid.js interactive
```

### REST API Examples

```bash
# Get authentication token
curl -X POST http://192.168.1.100:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'

# Check status (with token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://192.168.1.100:8081/api/status

# Start server
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"service":"webserver"}' \
  http://192.168.1.100:8081/api/service/start
```

## 📁 Directory Structure

```
~/webserver/
├── html/           # Web files (document root)
│   ├── remote.html # Remote control interface
│   ├── status.php  # Status dashboard
│   ├── api-docs.html # API documentation
│   └── edit.html   # File editor
├── logs/           # All log files
│   ├── access_log
│   ├── error_log
│   ├── api.log
│   └── watchdog.log
├── client/         # Client scripts
│   ├── connect.bat
│   ├── connect.sh
│   ├── webdroid_client.py
│   └── webdroid.js
├── api/            # API servers
│   └── flask_api.py
├── backup/         # Automated backups
├── ssl/            # SSL certificates
└── .htpasswd       # Authentication file
```

## 🔧 Configuration

### Environment Variables
```bash
# In ~/webserver/.env
JWT_SECRET=your-secret-key
ADMIN_USER=admin
ADMIN_PASS_HASH=hashed-password
```

### Change Default Ports
Edit the script variables before installation:
```bash
SERVER_PORT=8080    # Web server port
API_PORT=8081       # API server port
WEBSOCKET_PORT=8082 # WebSocket port
```

### Enable HTTPS
1. Place certificates in `~/webserver/ssl/`
2. Update Apache config to use SSL

## 📊 Monitoring

Access real-time monitoring:
- **Web Interface**: `http://[ip]:8080/status.php`
- **API**: `http://[ip]:8081/api/status`
- **WebSocket**: `ws://[ip]:8082`

## 🔒 Security

- JWT authentication for API
- Password-protected web interface
- Encrypted password storage
- `.htpasswd` for basic auth
- API key option for Python client
- Configurable CORS settings

## 📱 Requirements

- **Android**: 7.0 or higher
- **Termux**: Latest version from F-Droid
- **Storage**: ~1GB free space
- **Network**: Wi-Fi (both devices on same network)
- **Battery**: Disable optimization for Termux

## 🐛 Troubleshooting

### Can't connect from other device
```bash
# Check IP address
ip addr show

# Verify services are running
webserver status

# Check firewall (Android typically has none)
```

### Server won't start
```bash
# Run recovery
webserver recover

# Check logs
webserver logs error
```

### API not responding
```bash
# Restart API
webserver api restart
webserver api logs
```

### Battery killing Termux
```bash
# Get optimization help
webserver battery
```

### Connection refused
```bash
# Check if server is listening
netstat -tln | grep 8080

# Restart all services
webserver restart
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 👤 Author

**Taylor Christian Newsome** (ClumsyLulz)
- Email: SleepRaps@gmail.com
- GitHub: [@SleepTheGod](https://github.com/SleepTheGod)

## 🙏 Acknowledgments

- Termux team for the amazing terminal emulator
- Node.js and Python communities
- Apache Software Foundation
- All contributors and users

## 📚 Additional Resources

- [Termux Wiki](https://wiki.termux.com)
- [Apache Documentation](https://httpd.apache.org/docs/)
- [Node.js Documentation](https://nodejs.org/en/docs/)
- [WebSocket Protocol](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)

## ⚡ Quick Reference

```bash
# Installation
curl -sSL https://raw.githubusercontent.com/SleepTheGod/WebDroid/main/main.sh | bash

# Management
webserver remote     # Open remote control
webserver status     # Check all services
webserver logs       # View logs
webserver recover    # Fix crashes
webserver client     # Show client info

# Access URLs (replace IP with your device IP)
http://192.168.1.100:8080/remote.html  # Remote control
http://192.168.1.100:8080/status.php   # Monitoring
http://192.168.1.100:8081              # API endpoint
ws://192.168.1.100:8082                # WebSocket
```

---

**Made with ❤️ for the open-source community**

*Control your Android device from anywhere, on any platform!*
