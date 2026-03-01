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
