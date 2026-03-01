#!/data/data/com.termux/files/usr/bin/bash

# Android Local Web Server Setup Script
# For Termux (No root required) - PERSISTENT SERVER
# Author: Taylor Christian Newsome
# Email: SleepRaps@gmail.com
# Version: 3.0 - Cross Platform Control & Persistent

echo -e "| Made By Taylor Christian Newsome | ClumsyLulz |"

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
SERVER_ROOT="$HOME/webserver"
SERVER_PORT=8080
SERVER_IP=""
USERNAME="admin"
PASSWORD=""
PHP_VERSION="8.3"
TERMUX_BOOT="$HOME/.termux/boot"
TERMUX_SERVICE="$PREFIX/var/lib/termux-services"
API_PORT=8081
WEBSOCKET_PORT=8082
FTP_PORT=2121
SSH_PORT=8022
VNC_PORT=5901
RDP_PORT=3389

# Function to print colored output
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to get device IP address
get_ip_address() {
    # Try to get IP from different methods
    SERVER_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    fi
    
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="127.0.0.1"
    fi
    
    echo "$SERVER_IP"
}

# Function to check and request storage permission
check_storage_permission() {
    print_message "Checking storage permission..." "$YELLOW"
    
    if [ ! -d "$HOME/storage/shared" ]; then
        print_message "Requesting storage permission..." "$YELLOW"
        termux-setup-storage
        sleep 5
    fi
    
    if [ -d "$HOME/storage/shared" ]; then
        print_message "Storage permission granted!" "$GREEN"
    else
        print_message "Warning: Storage permission not granted. Some features may be limited." "$YELLOW"
    fi
}

# Function to update and upgrade packages
update_system() {
    print_message "Updating package lists..." "$YELLOW"
    pkg update -y && pkg upgrade -y
    
    if [ $? -eq 0 ]; then
        print_message "System updated successfully!" "$GREEN"
    else
        print_message "Failed to update system. Continuing anyway..." "$YELLOW"
    fi
}

# Function to install required packages
install_packages() {
    print_message "Installing required packages..." "$YELLOW"
    
    # Install essential packages
    pkg install -y apache2 php php-apache mariadb curl wget git nano vim openssh termux-services termux-tools termux-api nodejs python python3
    
    # Install persistent server tools
    pkg install -y tmux screen htop nload proot which figlet toilet nmap traceroute
    
    # Install autostart packages
    pkg install -y termux-services termux-exec
    
    # Install cross-platform control tools
    pkg install -y rsync openssh sftp sshpass autossh
    
    # Install Node.js packages for cross-platform API
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
        npm install -g http-server
        npm install -g localtunnel
        npm install -g ngrok
        npm install -g ws
        npm install -g express
        npm install -g socket.io
        npm install -g cors
        npm install -g body-parser
        npm install -g jsonwebtoken
        npm install -g bcryptjs
    fi
    
    # Install Python packages for advanced control
    pip install flask flask-cors flask-socketio flask-restful requests psutil
    
    if [ $? -eq 0 ]; then
        print_message "Packages installed successfully!" "$GREEN"
    else
        print_message "Failed to install some packages." "$RED"
        exit 1
    fi
}

# Function to enable termux-services
setup_termux_services() {
    print_message "Setting up termux-services for persistent operation..." "$YELLOW"
    
    # Create services directory
    mkdir -p "$TERMUX_SERVICE"
    
    # Create apache service
    cat > "$PREFIX/etc/termux-services/apache2" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
TERMUX_SERVICE_HOME=$HOME
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH

case $1 in
    start)
        echo "Starting Apache web server..."
        httpd -k start
        ;;
    stop)
        echo "Stopping Apache web server..."
        httpd -k stop
        ;;
    restart)
        echo "Restarting Apache web server..."
        httpd -k restart
        ;;
    status)
        if pgrep -x "httpd" > /dev/null; then
            echo "Apache is running"
            exit 0
        else
            echo "Apache is stopped"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$PREFIX/etc/termux-services/apache2"
    
    print_message "Termux-services configured!" "$GREEN"
}

# Function to setup boot scripts
setup_boot_scripts() {
    print_message "Setting up boot scripts for auto-start..." "$YELLOW"
    
    # Create boot directory
    mkdir -p "$TERMUX_BOOT"
    
    # Create boot script
    cat > "$TERMUX_BOOT/start-webserver" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Wait for network
sleep 10

# Start web server
httpd -k start

# Start API server
pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api 2>/dev/null

# Log startup
echo "$(date): Web server started from boot" >> $HOME/webserver/logs/boot.log

# Keep the script running to prevent termination
while true; do
    sleep 60
    # Check if server is running, restart if not
    if ! pgrep -x "httpd" > /dev/null; then
        echo "$(date): Server was down, restarting..." >> $HOME/webserver/logs/boot.log
        httpd -k start
    fi
done
EOF
    
    chmod +x "$TERMUX_BOOT/start-webserver"
    
    # Also create a backup boot script in Termux home
    cat > "$HOME/.termux_boot.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Auto-start web server on Termux launch
sleep 5
if ! pgrep -x "httpd" > /dev/null; then
    httpd -k start
    echo "$(date): Auto-started web server" >> $HOME/webserver/logs/auto.log
fi

# Start cross-platform services
pm2 resurrect 2>/dev/null || pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api 2>/dev/null
EOF
    
    chmod +x "$HOME/.termux_boot.sh"
    
    # Add to bashrc for auto-start on terminal open
    if ! grep -q ".termux_boot.sh" "$HOME/.bashrc"; then
        echo "# Auto-start web server (if not running)" >> "$HOME/.bashrc"
        echo "if [ -f \$HOME/.termux_boot.sh ]; then \$HOME/.termux_boot.sh; fi" >> "$HOME/.bashrc"
    fi
    
    print_message "Boot scripts created at $TERMUX_BOOT/" "$GREEN"
}

# Function to create watchdog script
create_watchdog() {
    print_message "Creating watchdog service for 24/7 operation..." "$YELLOW"
    
    # Create watchdog script
    cat > "$PREFIX/bin/webserver-watchdog" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Web Server Watchdog
# Ensures server runs 24/7 and restarts if crashed

LOG_FILE="$HOME/webserver/logs/watchdog.log"
PID_FILE="$HOME/webserver/webserver.pid"
CHECK_INTERVAL=30  # Check every 30 seconds

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check if server is running
check_server() {
    if pgrep -x "httpd" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to start server
start_server() {
    log_message "Starting web server..."
    httpd -k start
    
    # Wait and verify
    sleep 5
    if check_server; then
        log_message "Server started successfully"
        # Save PID
        pgrep -x "httpd" > "$PID_FILE"
    else
        log_message "ERROR: Failed to start server"
    fi
}

# Function to check resources
check_resources() {
    # Check CPU usage of httpd
    CPU_USAGE=$(ps -o pcpu -p $(pgrep -x httpd | head -1) 2>/dev/null | tail -1 | tr -d ' ')
    if [ ! -z "$CPU_USAGE" ] && [ $(echo "$CPU_USAGE > 90" | bc 2>/dev/null) -eq 1 ]; then
        log_message "WARNING: High CPU usage: $CPU_USAGE%"
    fi
    
    # Check memory usage
    MEM_USAGE=$(ps -o rss -p $(pgrep -x httpd | head -1) 2>/dev/null | tail -1 | tr -d ' ')
    if [ ! -z "$MEM_USAGE" ] && [ $MEM_USAGE -gt 500000 ]; then
        log_message "WARNING: High memory usage: $(($MEM_USAGE/1024)) MB"
    fi
}

# Main loop
log_message "Watchdog started with PID $$"
log_message "Checking every $CHECK_INTERVAL seconds"

while true; do
    if ! check_server; then
        log_message "Server not running! Attempting restart..."
        start_server
    else
        # Optional: Check resources occasionally
        if [ $((RANDOM % 10)) -eq 0 ]; then
            check_resources
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
EOF

    chmod +x "$PREFIX/bin/webserver-watchdog"
    
    # Create systemd-like service script
    cat > "$PREFIX/bin/webserver-service" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

case $1 in
    start)
        echo "Starting web server service..."
        nohup webserver-watchdog > /dev/null 2>&1 &
        echo $! > "$HOME/webserver/watchdog.pid"
        echo "Watchdog started with PID: $(cat $HOME/webserver/watchdog.pid)"
        ;;
    stop)
        echo "Stopping web server service..."
        if [ -f "$HOME/webserver/watchdog.pid" ]; then
            kill $(cat "$HOME/webserver/watchdog.pid") 2>/dev/null
            rm "$HOME/webserver/watchdog.pid"
        fi
        httpd -k stop
        pkill httpd 2>/dev/null
        echo "Service stopped"
        ;;
    status)
        if pgrep -x "httpd" > /dev/null; then
            echo "✅ Web server is RUNNING"
            echo "📊 Process IDs: $(pgrep -x httpd | tr '\n' ' ')"
            if [ -f "$HOME/webserver/watchdog.pid" ]; then
                echo "🐕 Watchdog is active"
            fi
        else
            echo "❌ Web server is NOT running"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    logs)
        tail -f "$HOME/webserver/logs/watchdog.log"
        ;;
    *)
        echo "Usage: webserver-service {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x "$PREFIX/bin/webserver-service"
    
    print_message "Watchdog service created!" "$GREEN"
}

# Function to create directory structure
create_directories() {
    print_message "Creating directory structure..." "$YELLOW"
    
    # Create web root directory
    mkdir -p "$SERVER_ROOT"
    mkdir -p "$SERVER_ROOT/html"
    mkdir -p "$SERVER_ROOT/logs"
    mkdir -p "$SERVER_ROOT/backup"
    mkdir -p "$SERVER_ROOT/ssl"
    mkdir -p "$SERVER_ROOT/cgi-bin"
    mkdir -p "$SERVER_ROOT/status"
    mkdir -p "$SERVER_ROOT/cron"
    mkdir -p "$SERVER_ROOT/api"
    mkdir -p "$SERVER_ROOT/remote"
    mkdir -p "$SERVER_ROOT/websocket"
    mkdir -p "$SERVER_ROOT/ftp"
    mkdir -p "$SERVER_ROOT/vnc"
    
    # Create public_html in shared storage for easy file access
    mkdir -p "$HOME/storage/shared/webserver_files"
    ln -sf "$HOME/storage/shared/webserver_files" "$SERVER_ROOT/html/shared" 2>/dev/null
    
    # Set permissions
    chmod 755 "$SERVER_ROOT"
    chmod 755 "$SERVER_ROOT/html"
    chmod 755 "$SERVER_ROOT/logs"
    
    # Create log files
    touch "$SERVER_ROOT/logs/error_log"
    touch "$SERVER_ROOT/logs/access_log"
    touch "$SERVER_ROOT/logs/watchdog.log"
    touch "$SERVER_ROOT/logs/boot.log"
    touch "$SERVER_ROOT/logs/auto.log"
    touch "$SERVER_ROOT/logs/remote.log"
    touch "$SERVER_ROOT/logs/api.log"
    
    print_message "Directory structure created successfully!" "$GREEN"
}

# Function to set admin password
set_admin_password() {
    print_message "Setting up admin password for web server..." "$YELLOW"
    
    # Generate a random password if not provided
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c 16)
        print_message "Generated random password: $PASSWORD" "$CYAN"
    fi
    
    # Save password to file (encrypted)
    echo "$PASSWORD" | openssl enc -aes-256-cbc -salt -out "$SERVER_ROOT/password.enc" -pass pass:termuxwebserver 2>/dev/null
    
    # Create .htpasswd file for basic authentication
    if command -v htpasswd &> /dev/null; then
        htpasswd -bc "$SERVER_ROOT/.htpasswd" "$USERNAME" "$PASSWORD" 2>/dev/null
    else
        pkg install -y apache2-utils
        htpasswd -bc "$SERVER_ROOT/.htpasswd" "$USERNAME" "$PASSWORD" 2>/dev/null
    fi
    
    # Generate JWT secret for API
    JWT_SECRET=$(tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c 32)
    echo "JWT_SECRET=$JWT_SECRET" > "$SERVER_ROOT/.env"
    echo "ADMIN_USER=$USERNAME" >> "$SERVER_ROOT/.env"
    echo "ADMIN_PASS_HASH=$(echo -n $PASSWORD | sha256sum | cut -d' ' -f1)" >> "$SERVER_ROOT/.env"
    
    print_message "Admin credentials saved for web server:" "$GREEN"
    print_message "Username: $USERNAME" "$CYAN"
    print_message "Password: $PASSWORD" "$CYAN"
}

# Function to configure Apache for Termux
configure_apache() {
    print_message "Configuring Apache web server for Termux..." "$YELLOW"
    
    APACHE_CONFIG="$PREFIX/etc/apache2/httpd.conf"
    
    # Backup original config
    if [ -f "$APACHE_CONFIG" ]; then
        cp "$APACHE_CONFIG" "$APACHE_CONFIG.backup"
    fi
    
    # Create Apache configuration for Termux
    cat > "$APACHE_CONFIG" << EOF
ServerRoot "$PREFIX"
Listen $SERVER_PORT
LoadModule authn_file_module libexec/apache2/mod_authn_file.so
LoadModule authn_core_module libexec/apache2/mod_authn_core.so
LoadModule authz_host_module libexec/apache2/mod_authz_host.so
LoadModule authz_groupfile_module libexec/apache2/mod_authz_groupfile.so
LoadModule authz_user_module libexec/apache2/mod_authz_user.so
LoadModule authz_core_module libexec/apache2/mod_authz_core.so
LoadModule access_compat_module libexec/apache2/mod_access_compat.so
LoadModule auth_basic_module libexec/apache2/mod_auth_basic.so
LoadModule reqtimeout_module libexec/apache2/mod_reqtimeout.so
LoadModule filter_module libexec/apache2/mod_filter.so
LoadModule mime_module libexec/apache2/mod_mime.so
LoadModule log_config_module libexec/apache2/mod_log_config.so
LoadModule env_module libexec/apache2/mod_env.so
LoadModule headers_module libexec/apache2/mod_headers.so
LoadModule setenvif_module libexec/apache2/mod_setenvif.so
LoadModule version_module libexec/apache2/mod_version.so
LoadModule unixd_module libexec/apache2/mod_unixd.so
LoadModule status_module libexec/apache2/mod_status.so
LoadModule autoindex_module libexec/apache2/mod_autoindex.so
LoadModule dir_module libexec/apache2/mod_dir.so
LoadModule alias_module libexec/apache2/mod_alias.so
LoadModule php_module libexec/apache2/libphp.so
LoadModule proxy_module libexec/apache2/mod_proxy.so
LoadModule proxy_http_module libexec/apache2/mod_proxy_http.so
LoadModule proxy_wstunnel_module libexec/apache2/mod_proxy_wstunnel.so
LoadModule rewrite_module libexec/apache2/mod_rewrite.so

<IfModule unixd_module>
User $(whoami)
Group $(id -gn)
</IfModule>

ServerAdmin admin@localhost
ServerName localhost:$SERVER_PORT

<Directory />
    AllowOverride none
    Require all denied
</Directory>

DocumentRoot "$SERVER_ROOT/html"
<Directory "$SERVER_ROOT/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    
    # Basic Authentication
    AuthType Basic
    AuthName "Restricted Access - Admin Login Required"
    AuthUserFile "$SERVER_ROOT/.htpasswd"
    Require valid-user
</Directory>

<IfModule dir_module>
    DirectoryIndex index.html index.php index.js
</IfModule>

<Files ".ht*">
    Require all denied
</Files>

ErrorLog "$SERVER_ROOT/logs/error_log"
LogLevel warn

<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common
    CustomLog "$SERVER_ROOT/logs/access_log" common
</IfModule>

<IfModule mime_module>
    TypesConfig conf/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType application/x-httpd-php .php
</IfModule>

<IfModule alias_module>
    ScriptAlias /cgi-bin/ "$SERVER_ROOT/cgi-bin/"
</IfModule>

<IfModule cgid_module>
    #Scriptsock cgisock
</IfModule>

<Directory "$SERVER_ROOT/cgi-bin">
    AllowOverride None
    Options None
    Require all granted
</Directory>

<IfModule headers_module>
    RequestHeader unset Proxy early
</IfModule>

# Status page for monitoring
<Location /server-status>
    SetHandler server-status
    Require all granted
</Location>

# API proxy
<Location /api>
    ProxyPass http://localhost:$API_PORT
    ProxyPassReverse http://localhost:$API_PORT
</Location>

# WebSocket proxy
<Location /ws>
    ProxyPass ws://localhost:$WEBSOCKET_PORT
    ProxyPassReverse ws://localhost:$WEBSOCKET_PORT
</Location>

# Keep alive settings for better performance
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Timeout settings
Timeout 300
EOF
    
    print_message "Apache configured successfully for Termux!" "$GREEN"
}

# Function to create cross-platform API
create_cross_platform_api() {
    print_message "Creating cross-platform control API..." "$YELLOW"
    
    # Create Node.js API server
    cat > "$PREFIX/bin/cross-platform-api" << 'EOF'
#!/data/data/com.termux/files/usr/bin/env node

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Configuration
const PORT = process.env.API_PORT || 8081;
const WS_PORT = process.env.WS_PORT || 8082;
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
const SERVER_ROOT = process.env.HOME + '/webserver';
const TOKEN_EXPIRY = '24h';

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Logger
const log = (type, message) => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${type}] ${message}\n`;
    fs.appendFileSync(`${SERVER_ROOT}/logs/api.log`, logMessage);
    console.log(logMessage.trim());
};

// Authentication middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'No token provided' });
    }
    
    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid token' });
        }
        req.user = user;
        next();
    });
};

// Load admin credentials
const loadAdminCreds = () => {
    try {
        const envFile = fs.readFileSync(`${SERVER_ROOT}/.env`, 'utf8');
        const creds = {};
        envFile.split('\n').forEach(line => {
            const [key, value] = line.split('=');
            if (key && value) creds[key] = value;
        });
        return creds;
    } catch (err) {
        return {
            ADMIN_USER: 'admin',
            ADMIN_PASS_HASH: crypto.createHash('sha256').update('admin').digest('hex')
        };
    }
};

// Routes
app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    const creds = loadAdminCreds();
    
    const passwordHash = crypto.createHash('sha256').update(password).digest('hex');
    
    if (username === creds.ADMIN_USER && passwordHash === creds.ADMIN_PASS_HASH) {
        const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: TOKEN_EXPIRY });
        log('AUTH', `User ${username} logged in`);
        res.json({ 
            token, 
            message: 'Authentication successful',
            expiresIn: TOKEN_EXPIRY
        });
    } else {
        log('AUTH', `Failed login attempt for ${username}`);
        res.status(401).json({ error: 'Invalid credentials' });
    }
});

// Server status
app.get('/api/status', authenticateToken, (req, res) => {
    exec('webserver-service status', (error, stdout, stderr) => {
        const uptime = os.uptime();
        const loadAvg = os.loadavg();
        const freeMem = os.freemem();
        const totalMem = os.totalmem();
        
        res.json({
            server: {
                status: stdout.includes('RUNNING') ? 'running' : 'stopped',
                uptime: uptime,
                loadAverage: loadAvg,
                memory: {
                    free: freeMem,
                    total: totalMem,
                    used: totalMem - freeMem,
                    percentage: ((totalMem - freeMem) / totalMem * 100).toFixed(2)
                },
                platform: os.platform(),
                hostname: os.hostname(),
                network: Object.values(os.networkInterfaces()).flat()
                    .filter(iface => iface.family === 'IPv4' && !iface.internal)
                    .map(iface => iface.address)
            },
            services: {
                apache: exec('pgrep httpd').toString().trim() ? 'running' : 'stopped',
                watchdog: fs.existsSync(`${SERVER_ROOT}/watchdog.pid`) ? 'running' : 'stopped',
                api: 'running'
            }
        });
    });
});

// File operations
app.get('/api/files/*', authenticateToken, (req, res) => {
    const filePath = path.join(SERVER_ROOT + '/html', req.params[0] || '');
    
    try {
        const stats = fs.statSync(filePath);
        
        if (stats.isDirectory()) {
            const files = fs.readdirSync(filePath).map(file => {
                const fileStats = fs.statSync(path.join(filePath, file));
                return {
                    name: file,
                    type: fileStats.isDirectory() ? 'directory' : 'file',
                    size: fileStats.size,
                    modified: fileStats.mtime,
                    permissions: fileStats.mode.toString(8).slice(-3)
                };
            });
            res.json({ path: req.params[0] || '/', files });
        } else {
            const content = fs.readFileSync(filePath, 'utf8');
            res.json({ 
                path: req.params[0],
                content,
                size: stats.size,
                modified: stats.mtime
            });
        }
    } catch (err) {
        res.status(404).json({ error: 'File not found' });
    }
});

app.post('/api/files/*', authenticateToken, (req, res) => {
    const filePath = path.join(SERVER_ROOT + '/html', req.params[0] || '');
    const { content } = req.body;
    
    try {
        fs.writeFileSync(filePath, content);
        log('FILE', `Modified: ${req.params[0]}`);
        res.json({ message: 'File saved successfully' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to save file' });
    }
});

// Command execution
app.post('/api/exec', authenticateToken, (req, res) => {
    const { command } = req.body;
    
    // Security: Only allow whitelisted commands
    const allowedCommands = [
        'webserver', 'ls', 'pwd', 'whoami', 'uptime',
        'ps aux | grep httpd', 'free -h', 'df -h', 'netstat -tln',
        'tail -n 50', 'cat', 'echo'
    ];
    
    if (!allowedCommands.some(cmd => command.startsWith(cmd))) {
        return res.status(403).json({ error: 'Command not allowed' });
    }
    
    exec(command, (error, stdout, stderr) => {
        log('EXEC', `Executed: ${command}`);
        res.json({
            command,
            stdout: stdout || '',
            stderr: stderr || '',
            error: error ? error.message : null
        });
    });
});

// Service control
app.post('/api/service/:action', authenticateToken, (req, res) => {
    const { action } = req.params;
    const { service } = req.body;
    
    const validActions = ['start', 'stop', 'restart'];
    const validServices = ['webserver', 'apache2', 'watchdog'];
    
    if (!validActions.includes(action)) {
        return res.status(400).json({ error: 'Invalid action' });
    }
    
    if (!validServices.includes(service)) {
        return res.status(400).json({ error: 'Invalid service' });
    }
    
    let command;
    if (service === 'webserver') {
        command = `webserver ${action}`;
    } else if (service === 'apache2') {
        command = `webserver-service ${action}`;
    } else if (service === 'watchdog') {
        command = `webserver-watchdog ${action}`;
    }
    
    exec(command, (error, stdout, stderr) => {
        if (error) {
            res.status(500).json({ error: error.message });
        } else {
            log('SERVICE', `${action}ed ${service}`);
            res.json({ message: `${service} ${action}ed successfully` });
        }
    });
});

// System info
app.get('/api/system', authenticateToken, (req, res) => {
    const cpus = os.cpus();
    const network = os.networkInterfaces();
    
    res.json({
        os: {
            type: os.type(),
            release: os.release(),
            arch: os.arch(),
            platform: os.platform()
        },
        cpu: {
            model: cpus[0].model,
            cores: cpus.length,
            speed: cpus[0].speed,
            usage: process.cpuUsage()
        },
        memory: {
            total: os.totalmem(),
            free: os.freemem(),
            used: os.totalmem() - os.freemem()
        },
        network: Object.keys(network).map(iface => ({
            interface: iface,
            addresses: network[iface].map(addr => ({
                address: addr.address,
                family: addr.family,
                internal: addr.internal
            }))
        })),
        uptime: os.uptime(),
        loadavg: os.loadavg()
    });
});

// Logs
app.get('/api/logs/:type', authenticateToken, (req, res) => {
    const { type } = req.params;
    const { lines = 100 } = req.query;
    
    const logFiles = {
        access: 'access_log',
        error: 'error_log',
        api: 'api.log',
        watchdog: 'watchdog.log',
        boot: 'boot.log'
    };
    
    if (!logFiles[type]) {
        return res.status(400).json({ error: 'Invalid log type' });
    }
    
    const logPath = path.join(SERVER_ROOT + '/logs', logFiles[type]);
    
    try {
        exec(`tail -n ${lines} ${logPath}`, (error, stdout, stderr) => {
            if (error) {
                res.status(500).json({ error: error.message });
            } else {
                res.json({ 
                    type,
                    lines: stdout.split('\n').filter(l => l.length > 0)
                });
            }
        });
    } catch (err) {
        res.status(404).json({ error: 'Log file not found' });
    }
});

// WebSocket for real-time updates
wss.on('connection', (ws) => {
    log('WS', 'New client connected');
    
    // Send initial status
    ws.send(JSON.stringify({ type: 'connected', message: 'Real-time monitoring active' }));
    
    // Set up interval for status updates
    const interval = setInterval(() => {
        exec('webserver-service status', (error, stdout, stderr) => {
            const status = stdout.includes('RUNNING') ? 'running' : 'stopped';
            ws.send(JSON.stringify({
                type: 'status',
                status,
                timestamp: Date.now(),
                cpu: os.loadavg()[0],
                memory: os.freemem() / os.totalmem() * 100
            }));
        });
    }, 5000);
    
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            log('WS', `Received: ${data.type}`);
            
            if (data.type === 'command') {
                exec(data.command, (error, stdout, stderr) => {
                    ws.send(JSON.stringify({
                        type: 'command_result',
                        command: data.command,
                        stdout,
                        stderr,
                        error: error ? error.message : null
                    }));
                });
            }
        } catch (err) {
            log('WS', `Error: ${err.message}`);
        }
    });
    
    ws.on('close', () => {
        clearInterval(interval);
        log('WS', 'Client disconnected');
    });
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
    log('API', `REST API running on port ${PORT}`);
    log('WS', `WebSocket running on port ${WS_PORT}`);
    log('AUTH', `JWT tokens expire in ${TOKEN_EXPIRY}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    log('SYSTEM', 'Received SIGTERM, shutting down...');
    server.close(() => {
        process.exit(0);
    });
});
EOF

    chmod +x "$PREFIX/bin/cross-platform-api"
    
    # Create PM2 ecosystem file
    cat > "$HOME/ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: 'webdroid-api',
    script: '/data/data/com.termux/files/usr/bin/cross-platform-api',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '100M',
    env: {
      NODE_ENV: 'production',
      API_PORT: $API_PORT,
      WS_PORT: $WEBSOCKET_PORT
    }
  }]
};
EOF

    print_message "Cross-platform API created!" "$GREEN"
}

# Function to create Python Flask API as backup
create_python_api() {
    print_message "Creating Python Flask API (backup)..." "$YELLOW"
    
    cat > "$SERVER_ROOT/api/flask_api.py" << 'EOF'
#!/data/data/com.termux/files/usr/bin/python3

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import subprocess
import os
import json
import psutil
import socket
import fcntl
import struct
import time
from datetime import datetime
import hashlib
import hmac

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# Configuration
SERVER_ROOT = os.environ.get('HOME', '') + '/webserver'
API_KEY_FILE = SERVER_ROOT + '/.api_key'

def get_ip_address(ifname):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(
            s.fileno(),
            0x8915,
            struct.pack('256s', ifname[:15].encode())
        )[20:24])
    except:
        return None

def authenticate():
    api_key = request.headers.get('X-API-Key')
    if not api_key:
        return False
    
    with open(API_KEY_FILE, 'r') as f:
        valid_key = f.read().strip()
    return hmac.compare_digest(api_key, valid_key)

@app.before_request
def before_request():
    if request.endpoint != 'get_api_key' and not authenticate():
        return jsonify({'error': 'Unauthorized'}), 401

@app.route('/api/key', methods=['GET'])
def get_api_key():
    with open(API_KEY_FILE, 'r') as f:
        key = f.read().strip()
    return jsonify({'api_key': key})

@app.route('/api/status', methods=['GET'])
def status():
    # Check server status
    result = subprocess.run(['pgrep', 'httpd'], capture_output=True)
    server_running = result.returncode == 0
    
    # System info
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    # Network interfaces
    interfaces = {}
    for iface in ['wlan0', 'eth0', 'rmnet0']:
        ip = get_ip_address(iface)
        if ip:
            interfaces[iface] = ip
    
    return jsonify({
        'server': {
            'status': 'running' if server_running else 'stopped',
            'port': 8080,
            'url': f"http://{interfaces.get('wlan0', 'localhost')}:8080"
        },
        'system': {
            'cpu': cpu_percent,
            'memory': {
                'total': memory.total,
                'available': memory.available,
                'percent': memory.percent
            },
            'disk': {
                'total': disk.total,
                'used': disk.used,
                'free': disk.free,
                'percent': disk.percent
            }
        },
        'network': interfaces,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/control/<action>', methods=['POST'])
def control(action):
    valid_actions = ['start', 'stop', 'restart']
    if action not in valid_actions:
        return jsonify({'error': 'Invalid action'}), 400
    
    try:
        if action == 'start':
            subprocess.run(['httpd', '-k', 'start'])
        elif action == 'stop':
            subprocess.run(['httpd', '-k', 'stop'])
        elif action == 'restart':
            subprocess.run(['httpd', '-k', 'restart'])
        
        return jsonify({'success': True, 'action': action})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/files', methods=['GET'])
def list_files():
    path = request.args.get('path', SERVER_ROOT + '/html')
    try:
        files = []
        for item in os.listdir(path):
            item_path = os.path.join(path, item)
            stat = os.stat(item_path)
            files.append({
                'name': item,
                'type': 'directory' if os.path.isdir(item_path) else 'file',
                'size': stat.st_size,
                'modified': datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
        return jsonify({'path': path, 'files': files})
    except Exception as e:
        return jsonify({'error': str(e)}), 404

@app.route('/api/file/<path:filepath>', methods=['GET', 'POST'])
def handle_file(filepath):
    full_path = os.path.join(SERVER_ROOT + '/html', filepath)
    
    if request.method == 'GET':
        try:
            if os.path.isfile(full_path):
                return send_file(full_path)
            else:
                return jsonify({'error': 'Not a file'}), 400
        except Exception as e:
            return jsonify({'error': str(e)}), 404
    
    elif request.method == 'POST':
        try:
            content = request.json.get('content', '')
            with open(full_path, 'w') as f:
                f.write(content)
            return jsonify({'success': True})
        except Exception as e:
            return jsonify({'error': str(e)}), 500

@app.route('/api/logs/<logtype>', methods=['GET'])
def get_logs(logtype):
    log_files = {
        'error': 'error_log',
        'access': 'access_log',
        'api': 'api.log'
    }
    
    if logtype not in log_files:
        return jsonify({'error': 'Invalid log type'}), 400
    
    log_path = os.path.join(SERVER_ROOT + '/logs', log_files[logtype])
    lines = request.args.get('lines', 100, type=int)
    
    try:
        result = subprocess.run(['tail', '-n', str(lines), log_path], 
                               capture_output=True, text=True)
        return jsonify({
            'type': logtype,
            'lines': result.stdout.splitlines()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@socketio.on('connect')
def handle_connect():
    emit('connected', {'data': 'Connected to WebDroid'})

@socketio.on('command')
def handle_command(data):
    try:
        result = subprocess.run(data['cmd'], shell=True, 
                               capture_output=True, text=True, timeout=30)
        emit('command_result', {
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        })
    except subprocess.TimeoutExpired:
        emit('command_result', {'error': 'Command timeout'})
    except Exception as e:
        emit('command_result', {'error': str(e)})

if __name__ == '__main__':
    # Generate API key
    api_key = hashlib.sha256(str(time.time()).encode()).hexdigest()[:32]
    with open(API_KEY_FILE, 'w') as f:
        f.write(api_key)
    
    print(f"API Key: {api_key}")
    print("Flask API starting on port 5000...")
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
EOF

    chmod +x "$SERVER_ROOT/api/flask_api.py"
    
    print_message "Python Flask API created!" "$GREEN"
}

# Function to create web-based remote control interface
create_remote_interface() {
    print_message "Creating web-based remote control interface..." "$YELLOW"
    
    # Create remote control HTML
    cat > "$SERVER_ROOT/html/remote.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebDroid Remote Control</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
        }
        .navbar {
            background: rgba(0,0,0,0.3);
            padding: 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            backdrop-filter: blur(10px);
        }
        .logo {
            font-size: 1.5rem;
            font-weight: bold;
        }
        .nav-links a {
            color: white;
            text-decoration: none;
            margin-left: 1.5rem;
            padding: 0.5rem 1rem;
            border-radius: 5px;
            transition: background 0.3s;
        }
        .nav-links a:hover, .nav-links a.active {
            background: rgba(255,255,255,0.2);
        }
        .container {
            max-width: 1400px;
            margin: 2rem auto;
            padding: 0 1rem;
        }
        .status-bar {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 1.5rem;
            margin-bottom: 2rem;
            backdrop-filter: blur(10px);
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }
        .status-item {
            text-align: center;
        }
        .status-label {
            font-size: 0.9rem;
            opacity: 0.8;
            margin-bottom: 0.5rem;
        }
        .status-value {
            font-size: 1.5rem;
            font-weight: bold;
        }
        .online { color: #4ade80; }
        .offline { color: #f87171; }
        .dashboard {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 1.5rem;
            margin-bottom: 1.5rem;
        }
        .card {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 1.5rem;
            backdrop-filter: blur(10px);
        }
        .card h2 {
            margin-bottom: 1rem;
            font-size: 1.2rem;
            color: rgba(255,255,255,0.9);
        }
        .control-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1rem;
            margin-bottom: 1rem;
        }
        .control-btn {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 1rem;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1rem;
            transition: all 0.3s;
        }
        .control-btn:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
        }
        .control-btn.start:hover { background: #4ade80; }
        .control-btn.stop:hover { background: #f87171; }
        .control-btn.restart:hover { background: #fbbf24; }
        .file-list {
            max-height: 300px;
            overflow-y: auto;
        }
        .file-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem;
            border-bottom: 1px solid rgba(255,255,255,0.1);
            cursor: pointer;
        }
        .file-item:hover {
            background: rgba(255,255,255,0.1);
        }
        .file-name {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        .file-size {
            font-size: 0.8rem;
            opacity: 0.7;
        }
        .terminal {
            background: #1e1e1e;
            border-radius: 10px;
            overflow: hidden;
            font-family: 'Courier New', monospace;
        }
        .terminal-header {
            background: #333;
            padding: 0.5rem 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .terminal-content {
            padding: 1rem;
            min-height: 200px;
            max-height: 400px;
            overflow-y: auto;
            color: #4ade80;
        }
        .terminal-input {
            display: flex;
            padding: 1rem;
            background: #2d2d2d;
        }
        .terminal-input input {
            flex: 1;
            background: #1e1e1e;
            border: none;
            color: #4ade80;
            padding: 0.5rem;
            font-family: 'Courier New', monospace;
            outline: none;
        }
        .terminal-input button {
            background: #4ade80;
            border: none;
            color: #1e1e1e;
            padding: 0.5rem 1rem;
            margin-left: 0.5rem;
            cursor: pointer;
            font-weight: bold;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 1rem;
            margin-top: 1rem;
        }
        .metric {
            text-align: center;
            padding: 1rem;
            background: rgba(255,255,255,0.05);
            border-radius: 5px;
        }
        .metric-value {
            font-size: 1.8rem;
            font-weight: bold;
            color: #4ade80;
        }
        .metric-label {
            font-size: 0.8rem;
            opacity: 0.7;
        }
        .tab-container {
            margin-top: 2rem;
        }
        .tabs {
            display: flex;
            gap: 0.5rem;
            margin-bottom: 1rem;
        }
        .tab {
            padding: 0.5rem 1rem;
            background: rgba(255,255,255,0.1);
            border: none;
            color: white;
            cursor: pointer;
            border-radius: 5px 5px 0 0;
        }
        .tab.active {
            background: rgba(255,255,255,0.2);
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        @media (max-width: 768px) {
            .dashboard {
                grid-template-columns: 1fr;
            }
            .control-grid {
                grid-template-columns: 1fr;
            }
        }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,.3);
            border-radius: 50%;
            border-top-color: #fff;
            animation: spin 1s ease-in-out infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .toast {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #333;
            color: white;
            padding: 1rem;
            border-radius: 5px;
            animation: slideIn 0.3s ease;
        }
        @keyframes slideIn {
            from {
                transform: translateX(100%);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="logo">🚀 WebDroid Remote Control</div>
        <div class="nav-links">
            <a href="#dashboard" class="active" onclick="showTab('dashboard')">Dashboard</a>
            <a href="#files" onclick="showTab('files')">Files</a>
            <a href="#terminal" onclick="showTab('terminal')">Terminal</a>
            <a href="#settings" onclick="showTab('settings')">Settings</a>
        </div>
    </div>

    <div class="container">
        <div class="status-bar">
            <div class="status-grid">
                <div class="status-item">
                    <div class="status-label">Server Status</div>
                    <div class="status-value" id="server-status">Checking...</div>
                </div>
                <div class="status-item">
                    <div class="status-label">Device IP</div>
                    <div class="status-value" id="device-ip">-</div>
                </div>
                <div class="status-item">
                    <div class="status-label">CPU Usage</div>
                    <div class="status-value" id="cpu-usage">-</div>
                </div>
                <div class="status-item">
                    <div class="status-label">Memory</div>
                    <div class="status-value" id="memory-usage">-</div>
                </div>
            </div>
        </div>

        <div id="dashboard" class="tab-content active">
            <div class="dashboard">
                <div class="card">
                    <h2>⚡ Quick Controls</h2>
                    <div class="control-grid">
                        <button class="control-btn start" onclick="controlServer('start')">▶ Start</button>
                        <button class="control-btn stop" onclick="controlServer('stop')">⏹ Stop</button>
                        <button class="control-btn restart" onclick="controlServer('restart')">🔄 Restart</button>
                    </div>
                    
                    <h2 style="margin-top: 2rem;">📊 System Metrics</h2>
                    <div class="metrics">
                        <div class="metric">
                            <div class="metric-value" id="cpu-value">0%</div>
                            <div class="metric-label">CPU</div>
                        </div>
                        <div class="metric">
                            <div class="metric-value" id="memory-value">0%</div>
                            <div class="metric-label">Memory</div>
                        </div>
                        <div class="metric">
                            <div class="metric-value" id="disk-value">0%</div>
                            <div class="metric-label">Disk</div>
                        </div>
                        <div class="metric">
                            <div class="metric-value" id="uptime-value">0d</div>
                            <div class="metric-label">Uptime</div>
                        </div>
                    </div>

                    <h2 style="margin-top: 2rem;">🌐 Network Interfaces</h2>
                    <div id="network-interfaces"></div>
                </div>

                <div class="card">
                    <h2>📋 Recent Logs</h2>
                    <div class="file-list" id="recent-logs">
                        <div class="loading"></div>
                    </div>
                </div>
            </div>
        </div>

        <div id="files" class="tab-content">
            <div class="card">
                <h2>📁 File Manager</h2>
                <div style="margin-bottom: 1rem;">
                    <input type="text" id="current-path" value="/" readonly style="width: 100%; padding: 0.5rem; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color: white; border-radius: 5px;">
                </div>
                <div class="file-list" id="file-list"></div>
            </div>
        </div>

        <div id="terminal" class="tab-content">
            <div class="terminal">
                <div class="terminal-header">
                    <span>📟 Termux Terminal</span>
                    <span>Remote Access</span>
                </div>
                <div class="terminal-content" id="terminal-output"></div>
                <div class="terminal-input">
                    <input type="text" id="terminal-input" placeholder="Enter command..." onkeypress="handleTerminalKeypress(event)">
                    <button onclick="sendTerminalCommand()">Send</button>
                </div>
            </div>
        </div>

        <div id="settings" class="tab-content">
            <div class="card">
                <h2>⚙️ Settings</h2>
                
                <h3 style="margin: 1rem 0;">Authentication</h3>
                <div style="margin-bottom: 1rem;">
                    <label style="display: block; margin-bottom: 0.5rem;">API Token</label>
                    <input type="text" id="api-token" readonly style="width: 100%; padding: 0.5rem; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color: white; border-radius: 5px;">
                </div>

                <h3 style="margin: 1rem 0;">Auto-Start</h3>
                <div style="margin-bottom: 1rem;">
                    <label>
                        <input type="checkbox" id="auto-start" onclick="toggleAutoStart()"> Enable auto-start on boot
                    </label>
                </div>

                <h3 style="margin: 1rem 0;">Services</h3>
                <div id="services-status"></div>

                <button class="control-btn" onclick="saveSettings()" style="width: 100%; margin-top: 1rem;">Save Settings</button>
            </div>
        </div>
    </div>

    <script>
        let ws = null;
        let jwtToken = localStorage.getItem('token');
        let refreshInterval = null;
        let currentPath = '/';

        // Initialize connection
        async function init() {
            // Try to get token if not present
            if (!jwtToken) {
                await login();
            }
            
            // Start WebSocket connection
            connectWebSocket();
            
            // Start status updates
            startStatusUpdates();
            
            // Load initial data
            loadStatus();
            loadFiles(currentPath);
        }

        async function login() {
            const password = prompt('Enter admin password:');
            if (!password) return;

            try {
                const response = await fetch('/api/auth/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username: 'admin', password })
                });
                
                const data = await response.json();
                if (data.token) {
                    jwtToken = data.token;
                    localStorage.setItem('token', jwtToken);
                }
            } catch (err) {
                console.error('Login failed:', err);
            }
        }

        function connectWebSocket() {
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const host = window.location.hostname;
            ws = new WebSocket(`${protocol}//${host}:8082`);
            
            ws.onopen = () => {
                console.log('WebSocket connected');
                showToast('Real-time connection established');
            };
            
            ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                handleWebSocketMessage(data);
            };
            
            ws.onclose = () => {
                console.log('WebSocket disconnected');
                setTimeout(connectWebSocket, 5000);
            };
        }

        function handleWebSocketMessage(data) {
            switch (data.type) {
                case 'status':
                    updateMetrics(data);
                    break;
                case 'command_result':
                    appendToTerminal(`$ ${data.command}\n${data.stdout || data.stderr || ''}`);
                    break;
            }
        }

        function startStatusUpdates() {
            refreshInterval = setInterval(loadStatus, 5000);
        }

        async function loadStatus() {
            try {
                const response = await fetch('/api/status', {
                    headers: { 'Authorization': `Bearer ${jwtToken}` }
                });
                const data = await response.json();
                updateUI(data);
            } catch (err) {
                console.error('Failed to load status:', err);
            }
        }

        function updateUI(data) {
            // Update status
            const statusEl = document.getElementById('server-status');
            statusEl.innerHTML = data.server.status === 'running' ? 
                '<span class="online">● ONLINE</span>' : 
                '<span class="offline">● OFFLINE</span>';
            
            // Update metrics
            document.getElementById('cpu-usage').textContent = `${data.system.cpu || 0}%`;
            document.getElementById('memory-usage').textContent = `${data.system.memory?.percent || 0}%`;
            document.getElementById('device-ip').textContent = data.server.network?.[0] || '-';
            
            // Update metric cards
            document.getElementById('cpu-value').textContent = `${data.system.cpu || 0}%`;
            document.getElementById('memory-value').textContent = `${data.system.memory?.percent || 0}%`;
            document.getElementById('disk-value').textContent = `${data.system.disk?.percent || 0}%';
            
            // Calculate uptime
            const uptime = data.server.uptime || 0;
            const days = Math.floor(uptime / 86400);
            document.getElementById('uptime-value').textContent = `${days}d`;
            
            // Network interfaces
            const networkHtml = data.server.network?.map(ip => 
                `<div style="padding: 0.5rem; background: rgba(255,255,255,0.05); margin: 0.25rem 0; border-radius: 5px;">🌐 ${ip}</div>`
            ).join('') || 'No network interfaces';
            document.getElementById('network-interfaces').innerHTML = networkHtml;
        }

        function updateMetrics(data) {
            // Update via WebSocket
        }

        async function controlServer(action) {
            try {
                const response = await fetch(`/api/service/${action}`, {
                    method: 'POST',
                    headers: { 
                        'Authorization': `Bearer ${jwtToken}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ service: 'webserver' })
                });
                
                if (response.ok) {
                    showToast(`Server ${action}ed successfully`);
                    loadStatus();
                }
            } catch (err) {
                showToast(`Failed to ${action} server`, 'error');
            }
        }

        async function loadFiles(path) {
            currentPath = path;
            document.getElementById('current-path').value = path;
            
            try {
                const response = await fetch(`/api/files${path}`, {
                    headers: { 'Authorization': `Bearer ${jwtToken}` }
                });
                const data = await response.json();
                
                const fileList = document.getElementById('file-list');
                if (data.files) {
                    fileList.innerHTML = data.files.map(file => `
                        <div class="file-item" onclick="handleFileClick('${file.name}', '${file.type}')">
                            <span class="file-name">
                                ${file.type === 'directory' ? '📁' : '📄'} ${file.name}
                            </span>
                            <span class="file-size">${formatBytes(file.size)}</span>
                        </div>
                    `).join('');
                }
            } catch (err) {
                console.error('Failed to load files:', err);
            }
        }

        function handleFileClick(name, type) {
            if (type === 'directory') {
                loadFiles(currentPath + (currentPath.endsWith('/') ? name : '/' + name));
            } else {
                // Handle file view/edit
                window.location.href = `/remote/edit.html?path=${encodeURIComponent(currentPath + '/' + name)}`;
            }
        }

        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }

        async function sendTerminalCommand() {
            const input = document.getElementById('terminal-input');
            const command = input.value.trim();
            if (!command) return;
            
            appendToTerminal(`$ ${command}`);
            
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'command',
                    command: command
                }));
            }
            
            input.value = '';
        }

        function handleTerminalKeypress(event) {
            if (event.key === 'Enter') {
                sendTerminalCommand();
            }
        }

        function appendToTerminal(text) {
            const output = document.getElementById('terminal-output');
            output.innerHTML += `<div>${text}</div>`;
            output.scrollTop = output.scrollHeight;
        }

        function showTab(tabName) {
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            document.getElementById(tabName).classList.add('active');
            
            document.querySelectorAll('.nav-links a').forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === `#${tabName}`) {
                    link.classList.add('active');
                }
            });
        }

        function showToast(message, type = 'success') {
            const toast = document.createElement('div');
            toast.className = 'toast';
            toast.style.background = type === 'success' ? '#4ade80' : '#f87171';
            toast.style.color = type === 'success' ? '#1e1e1e' : 'white';
            toast.textContent = message;
            
            document.body.appendChild(toast);
            
            setTimeout(() => {
                toast.remove();
            }, 3000);
        }

        async function toggleAutoStart() {
            const enabled = document.getElementById('auto-start').checked;
            try {
                await fetch(`/api/service/${enabled ? 'enable' : 'disable'}`, {
                    method: 'POST',
                    headers: { 
                        'Authorization': `Bearer ${jwtToken}`,
                        'Content-Type': 'application/json'
                    }
                });
                showToast(`Auto-start ${enabled ? 'enabled' : 'disabled'}`);
            } catch (err) {
                showToast('Failed to toggle auto-start', 'error');
            }
        }

        function saveSettings() {
            showToast('Settings saved');
        }

        // Initialize on load
        document.addEventListener('DOMContentLoaded', init);
    </script>
</body>
</html>
EOF

    # Create file editor
    cat > "$SERVER_ROOT/html/edit.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>File Editor - WebDroid</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 {
            margin-top: 0;
            border-bottom: 2px solid rgba(255,255,255,0.2);
            padding-bottom: 10px;
        }
        .path {
            background: rgba(0,0,0,0.3);
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
            font-family: monospace;
        }
        textarea {
            width: 100%;
            height: 400px;
            background: #1e1e1e;
            color: #4ade80;
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 5px;
            padding: 10px;
            font-family: 'Courier New', monospace;
            resize: vertical;
            margin-bottom: 20px;
        }
        .buttons {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        button {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1rem;
            transition: all 0.3s;
        }
        .save {
            background: #4ade80;
            color: #1e1e1e;
        }
        .save:hover {
            background: #22c55e;
        }
        .cancel {
            background: #f87171;
            color: white;
        }
        .cancel:hover {
            background: #ef4444;
        }
        .back {
            background: rgba(255,255,255,0.2);
            color: white;
        }
        .back:hover {
            background: rgba(255,255,255,0.3);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📝 File Editor</h1>
        <div class="path" id="file-path"></div>
        <textarea id="file-content" placeholder="Loading file content..."></textarea>
        <div class="buttons">
            <button class="save" onclick="saveFile()">💾 Save</button>
            <button class="cancel" onclick="window.location.href='remote.html'">✖ Cancel</button>
            <button class="back" onclick="window.location.href='remote.html#files'">◀ Back to Files</button>
        </div>
    </div>

    <script>
        const urlParams = new URLSearchParams(window.location.search);
        const filePath = urlParams.get('path');
        const token = localStorage.getItem('token');

        document.getElementById('file-path').textContent = filePath;

        async function loadFile() {
            try {
                const response = await fetch(`/api/files${filePath}`, {
                    headers: { 'Authorization': `Bearer ${token}` }
                });
                const data = await response.json();
                document.getElementById('file-content').value = data.content || '';
            } catch (err) {
                alert('Failed to load file');
            }
        }

        async function saveFile() {
            const content = document.getElementById('file-content').value;
            try {
                const response = await fetch(`/api/files${filePath}`, {
                    method: 'POST',
                    headers: { 
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ content })
                });
                
                if (response.ok) {
                    alert('File saved successfully');
                }
            } catch (err) {
                alert('Failed to save file');
            }
        }

        loadFile();
    </script>
</body>
</html>
EOF

    chmod 644 "$SERVER_ROOT/html/remote.html"
    chmod 644 "$SERVER_ROOT/html/edit.html"
    
    print_message "Remote control interface created!" "$GREEN"
}

# Function to create cross-platform client scripts
create_client_scripts() {
    print_message "Creating cross-platform client scripts..." "$YELLOW"
    
    # Create Windows batch file
    cat > "$SERVER_ROOT/client/connect.bat" << 'EOF'
@echo off
echo WebDroid Remote Control Client for Windows
echo ==========================================
echo.

set /p ip="Enter Android device IP: "
set /p port="Enter port (default 8080): "
if "%port%"=="" set port=8080

echo.
echo Connecting to http://%ip%:%port% ...
echo.

start http://%ip%:%port%/remote.html

echo.
echo Also available:
echo - API: http://%ip%:8081
echo - WebSocket: ws://%ip%:8082
echo.

pause
EOF

    # Create Linux/Mac script
    cat > "$SERVER_ROOT/client/connect.sh" << 'EOF'
#!/bin/bash

echo "WebDroid Remote Control Client for Linux/Mac"
echo "=========================================="
echo

read -p "Enter Android device IP: " ip
read -p "Enter port (default 8080): " port
port=${port:-8080}

echo
echo "Connecting to http://$ip:$port ..."
echo

# Try to open browser
if command -v xdg-open &> /dev/null; then
    xdg-open "http://$ip:$port/remote.html"
elif command -v open &> /dev/null; then
    open "http://$ip:$port/remote.html"
else
    echo "Please open: http://$ip:$port/remote.html"
fi

echo
echo "Also available:"
echo "- API: http://$ip:8081"
echo "- WebSocket: ws://$ip:8082"
echo

read -p "Press Enter to continue..."
EOF
    chmod +x "$SERVER_ROOT/client/connect.sh"

    # Create Python client
    cat > "$SERVER_ROOT/client/webdroid_client.py" << 'EOF'
#!/usr/bin/env python3

import requests
import json
import sys
import os
from datetime import datetime

class WebDroidClient:
    def __init__(self, host, port=8080, token=None):
        self.base_url = f"http://{host}:{port}"
        self.api_url = f"http://{host}:8081"
        self.token = token
        
    def authenticate(self, password):
        response = requests.post(
            f"{self.api_url}/api/auth/login",
            json={"username": "admin", "password": password}
        )
        if response.status_code == 200:
            self.token = response.json()['token']
            return True
        return False
    
    def get_status(self):
        headers = {'Authorization': f'Bearer {self.token}'}
        response = requests.get(f"{self.api_url}/api/status", headers=headers)
        return response.json()
    
    def control_server(self, action):
        headers = {
            'Authorization': f'Bearer {self.token}',
            'Content-Type': 'application/json'
        }
        response = requests.post(
            f"{self.api_url}/api/service/{action}",
            headers=headers,
            json={"service": "webserver"}
        )
        return response.json()
    
    def list_files(self, path="/"):
        headers = {'Authorization': f'Bearer {self.token}'}
        response = requests.get(f"{self.api_url}/api/files{path}", headers=headers)
        return response.json()
    
    def get_file(self, path):
        headers = {'Authorization': f'Bearer {self.token}'}
        response = requests.get(f"{self.api_url}/api/files{path}", headers=headers)
        return response.json()
    
    def save_file(self, path, content):
        headers = {
            'Authorization': f'Bearer {self.token}',
            'Content-Type': 'application/json'
        }
        response = requests.post(
            f"{self.api_url}/api/files{path}",
            headers=headers,
            json={"content": content}
        )
        return response.json()
    
    def execute_command(self, command):
        headers = {
            'Authorization': f'Bearer {self.token}',
            'Content-Type': 'application/json'
        }
        response = requests.post(
            f"{self.api_url}/api/exec",
            headers=headers,
            json={"command": command}
        )
        return response.json()

def main():
    if len(sys.argv) < 2:
        print("Usage: python webdroid_client.py <command> [arguments]")
        print("\nCommands:")
        print("  status                    - Check server status")
        print("  start                     - Start server")
        print("  stop                      - Stop server")
        print("  restart                   - Restart server")
        print("  ls [path]                 - List files")
        print("  cat <file>                 - View file")
        print("  edit <file> <content>      - Edit file")
        print("  exec <command>             - Execute command")
        print("  monitor                    - Open monitoring")
        sys.exit(1)
    
    host = input("Enter Android device IP: ")
    client = WebDroidClient(host)
    
    # Authenticate
    password = input("Enter admin password: ")
    if not client.authenticate(password):
        print("Authentication failed")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "status":
        status = client.get_status()
        print(json.dumps(status, indent=2))
    
    elif command in ["start", "stop", "restart"]:
        result = client.control_server(command)
        print(result)
    
    elif command == "ls":
        path = sys.argv[2] if len(sys.argv) > 2 else "/"
        files = client.list_files(path)
        for f in files.get('files', []):
            print(f"{f['type']} {f['name']} {f['size']} bytes")
    
    elif command == "cat":
        if len(sys.argv) < 3:
            print("Usage: cat <file>")
            sys.exit(1)
        file_data = client.get_file(sys.argv[2])
        print(file_data.get('content', ''))
    
    elif command == "exec":
        if len(sys.argv) < 3:
            print("Usage: exec <command>")
            sys.exit(1)
        result = client.execute_command(' '.join(sys.argv[2:]))
        print(result.get('stdout', ''))
        if result.get('stderr'):
            print("Error:", result['stderr'])

if __name__ == "__main__":
    main()
EOF

    # Create Node.js client
    cat > "$SERVER_ROOT/client/webdroid.js" << 'EOF'
#!/usr/bin/env node

const axios = require('axios');
const readline = require('readline');
const WebSocket = require('ws');
const chalk = require('chalk');

class WebDroidClient {
    constructor(host, port = 8080) {
        this.baseUrl = `http://${host}:${port}`;
        this.apiUrl = `http://${host}:8081`;
        this.wsUrl = `ws://${host}:8082`;
        this.token = null;
    }
    
    async authenticate(password) {
        try {
            const response = await axios.post(`${this.apiUrl}/api/auth/login`, {
                username: 'admin',
                password: password
            });
            this.token = response.data.token;
            return true;
        } catch (error) {
            console.error(chalk.red('Authentication failed:'), error.message);
            return false;
        }
    }
    
    async getStatus() {
        try {
            const response = await axios.get(`${this.apiUrl}/api/status`, {
                headers: { Authorization: `Bearer ${this.token}` }
            });
            return response.data;
        } catch (error) {
            throw error;
        }
    }
    
    async controlServer(action) {
        try {
            const response = await axios.post(`${this.apiUrl}/api/service/${action}`,
                { service: 'webserver' },
                { headers: { Authorization: `Bearer ${this.token}` } }
            );
            return response.data;
        } catch (error) {
            throw error;
        }
    }
    
    connectWebSocket() {
        const ws = new WebSocket(this.wsUrl);
        
        ws.on('open', () => {
            console.log(chalk.green('✓ WebSocket connected'));
        });
        
        ws.on('message', (data) => {
            const message = JSON.parse(data);
            console.log(chalk.cyan('[WS]'), message);
        });
        
        ws.on('close', () => {
            console.log(chalk.yellow('! WebSocket disconnected'));
        });
        
        return ws;
    }
    
    async interactive() {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
        
        console.log(chalk.cyan('\n📱 WebDroid Interactive Shell\n'));
        
        const showHelp = () => {
            console.log(chalk.yellow('\nCommands:'));
            console.log('  status     - Show server status');
            console.log('  start      - Start server');
            console.log('  stop       - Stop server');
            console.log('  restart    - Restart server');
            console.log('  monitor    - Start real-time monitoring');
            console.log('  exit       - Exit shell');
            console.log('  help       - Show this help\n');
        };
        
        showHelp();
        
        const ask = () => {
            rl.question(chalk.green('webdroid> '), async (cmd) => {
                switch(cmd.trim().toLowerCase()) {
                    case 'status':
                        try {
                            const status = await this.getStatus();
                            console.log(chalk.cyan('\nServer Status:'));
                            console.log(JSON.stringify(status, null, 2));
                        } catch (error) {
                            console.log(chalk.red('Error:'), error.message);
                        }
                        break;
                        
                    case 'start':
                    case 'stop':
                    case 'restart':
                        try {
                            const result = await this.controlServer(cmd);
                            console.log(chalk.green('✓'), result.message);
                        } catch (error) {
                            console.log(chalk.red('Error:'), error.message);
                        }
                        break;
                        
                    case 'monitor':
                        console.log(chalk.yellow('Starting real-time monitoring...'));
                        const ws = this.connectWebSocket();
                        break;
                        
                    case 'help':
                        showHelp();
                        break;
                        
                    case 'exit':
                        rl.close();
                        return;
                        
                    default:
                        console.log(chalk.red('Unknown command. Type help for commands.'));
                }
                ask();
            });
        };
        
        ask();
    }
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 1) {
        console.log(chalk.yellow('Usage:'));
        console.log('  node webdroid.js <command> [arguments]');
        console.log('\nCommands:');
        console.log('  status                    - Check server status');
        console.log('  start                     - Start server');
        console.log('  stop                      - Stop server');
        console.log('  restart                   - Restart server');
        console.log('  monitor                   - Real-time monitoring');
        console.log('  interactive                - Interactive shell');
        process.exit(1);
    }
    
    const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
    });
    
    const askQuestion = (query) => {
        return new Promise(resolve => {
            readline.question(query, resolve);
        });
    };
    
    const host = await askQuestion('Enter Android device IP: ');
    const client = new WebDroidClient(host);
    
    const password = await askQuestion('Enter admin password: ');
    if (!await client.authenticate(password)) {
        console.log(chalk.red('Authentication failed'));
        process.exit(1);
    }
    console.log(chalk.green('✓ Authenticated\n'));
    
    const command = args[0];
    
    try {
        if (command === 'status') {
            const status = await client.getStatus();
            console.log(JSON.stringify(status, null, 2));
        }
        else if (['start', 'stop', 'restart'].includes(command)) {
            const result = await client.controlServer(command);
            console.log(result.message);
        }
        else if (command === 'monitor') {
            client.connectWebSocket();
        }
        else if (command === 'interactive') {
            await client.interactive();
        }
    } catch (error) {
        console.log(chalk.red('Error:'), error.message);
    }
    
    readline.close();
}

if (require.main === module) {
    main();
}
EOF

    # Create README for clients
    cat > "$SERVER_ROOT/client/README.md" << 'EOF'
# WebDroid Remote Clients

This directory contains client scripts to control your Android web server from any platform.

## Available Clients

### Windows
- `connect.bat` - Simple batch file to open web interface

### Linux/Mac
- `connect.sh` - Shell script to open web interface

### Python
- `webdroid_client.py` - Full-featured Python client
  ```bash
  pip install requests
  python webdroid_client.py status
  ```

### Node.js
- `webdroid.js` - Node.js client with interactive shell
  ```bash
  npm install axios ws chalk
  node webdroid.js interactive
  ```

## Connection Information

After installation on your Android device:
- Web Interface: http://[device-ip]:8080/remote.html
- API Endpoint: http://[device-ip]:8081
- WebSocket: ws://[device-ip]:8082
- Default username: admin
- Password: [shown during installation]

## Features

- Real-time server monitoring
- File manager (upload/download/edit)
- Terminal access
- Service control (start/stop/restart)
- System metrics visualization
- Log viewer

## Requirements

- Android device with Termux and WebDroid installed
- Both devices on the same network
- Admin password from installation
EOF

    print_message "Cross-platform client scripts created!" "$GREEN"
}

# Function to create persistent script
create_persistent_script() {
    print_message "Creating persistent server runner..." "$YELLOW"
    
    # Create tmux session script
    cat > "$PREFIX/bin/webserver-persist" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Persistent web server using tmux
SESSION_NAME="webserver"

case $1 in
    start)
        # Check if session exists
        tmux has-session -t $SESSION_NAME 2>/dev/null
        
        if [ $? != 0 ]; then
            # Create new detached session
            tmux new-session -d -s $SESSION_NAME -n webserver
            
            # Send commands to session
            tmux send-keys -t $SESSION_NAME "echo 'Starting persistent web server...'" C-m
            tmux send-keys -t $SESSION_NAME "httpd -k start" C-m
            tmux send-keys -t $SESSION_NAME "echo 'Server running. Use Ctrl+B, D to detach'" C-m
            tmux send-keys -t $SESSION_NAME "webserver-watchdog &" C-m
            tmux send-keys -t $SESSION_NAME "pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api" C-m
            
            echo "✅ Persistent web server started in tmux session"
            echo "📊 Session name: $SESSION_NAME"
            echo "💡 To attach: tmux attach -t $SESSION_NAME"
        else
            echo "❌ Session already exists"
            echo "💡 To attach: tmux attach -t $SESSION_NAME"
        fi
        ;;
    
    stop)
        tmux send-keys -t $SESSION_NAME C-c
        tmux send-keys -t $SESSION_NAME "httpd -k stop" C-m
        sleep 2
        tmux kill-session -t $SESSION_NAME 2>/dev/null
        pkill -f webserver-watchdog 2>/dev/null
        pm2 kill 2>/dev/null
        echo "✅ Persistent web server stopped"
        ;;
    
    attach)
        tmux attach -t $SESSION_NAME
        ;;
    
    status)
        if tmux has-session -t $SESSION_NAME 2>/dev/null; then
            echo "✅ Persistent server is running"
            tmux list-windows -t $SESSION_NAME
        else
            echo "❌ Persistent server is not running"
        fi
        ;;
    
    logs)
        tail -f "$HOME/webserver/logs/watchdog.log"
        ;;
    
    *)
        echo "Usage: webserver-persist {start|stop|status|attach|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x "$PREFIX/bin/webserver-persist"
    
    print_message "Persistent server script created!" "$GREEN"
}

# Function to configure battery optimization bypass
configure_battery() {
    print_message "Configuring battery optimization settings..." "$YELLOW"
    
    # Create battery optimization script
    cat > "$PREFIX/bin/optimize-battery" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

echo "⚡ Battery Optimization Configuration"
echo "======================================"
echo ""
echo "To prevent Termux from being killed by battery optimization:"
echo ""
echo "1. Open Android Settings"
echo "2. Go to Apps > Termux"
echo "3. Select 'Battery' or 'Battery optimization'"
echo "4. Choose 'Don't optimize' or 'Unrestricted'"
echo ""
echo "Alternative methods:"
echo ""
# Try to request ignoring battery optimizations using Termux:API
if command -v termux-battery-status &> /dev/null; then
    echo "Attempting to request battery optimization exemption..."
    termux-battery-status
    echo "Check your device for a permission dialog"
fi

echo ""
echo "Also, add Termux to 'Protected apps' or 'Auto-start' list"
echo "in your device settings if available."
EOF

    chmod +x "$PREFIX/bin/optimize-battery"
    
    # Create keep-alive script
    cat > "$PREFIX/bin/keep-alive" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Keep device awake using Termux:WakeLock
while true; do
    # Acquire wakelock to prevent CPU sleep
    termux-wake-lock
    
    # Do some light activity every minute
    sleep 60
    
    # Check server status
    if ! pgrep -x "httpd" > /dev/null; then
        echo "$(date): Server died, restarting..." >> "$HOME/webserver/logs/keepalive.log"
        httpd -k start
    fi
    
    # Check API status
    if ! pgrep -f "cross-platform-api" > /dev/null; then
        echo "$(date): API died, restarting..." >> "$HOME/webserver/logs/keepalive.log"
        pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api
    fi
    
    # Release and reacquire wakelock every hour to prevent issues
    if [ $((SECONDS % 3600)) -eq 0 ]; then
        termux-wake-unlock
        sleep 2
        termux-wake-lock
    fi
done
EOF

    chmod +x "$PREFIX/bin/keep-alive"
    
    print_message "Battery optimization helpers created!" "$GREEN"
}

# Function to create monitoring dashboard
create_monitoring() {
    print_message "Creating monitoring dashboard..." "$YELLOW"
    
    # Create status page
    cat > "$SERVER_ROOT/html/status.php" << 'EOF'
<?php
// Simple status page
$uptime = shell_exec('uptime');
$server_status = shell_exec('pgrep httpd | wc -l');
$memory = shell_exec('free -h');
$disk = shell_exec('df -h ' . $_SERVER['DOCUMENT_ROOT']);
$logs = file_get_contents($_SERVER['DOCUMENT_ROOT'] . '/../logs/error_log');
$last_lines = array_slice(explode("\n", $logs), -20);

header('Refresh: 30'); // Auto-refresh every 30 seconds
?>
<!DOCTYPE html>
<html>
<head>
    <title>Server Status</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial; background: #f5f5f5; margin: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #00b09b; padding-bottom: 10px; }
        .status { padding: 10px; border-radius: 5px; margin: 10px 0; }
        .running { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .stopped { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: monospace; border: 1px solid #dee2e6; }
        .timestamp { color: #6c757d; font-size: 0.9em; margin-top: 10px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: #f8f9fa; padding: 15px; border-radius: 5px; border: 1px solid #dee2e6; }
        .card h3 { margin-top: 0; color: #495057; }
        .value { font-size: 1.5em; font-weight: bold; color: #00b09b; }
        .nav { margin-bottom: 20px; }
        .nav a { display: inline-block; padding: 10px 20px; background: #00b09b; color: white; text-decoration: none; border-radius: 5px; margin-right: 10px; }
        .nav a:hover { background: #008b7a; }
    </style>
</head>
<body>
    <div class="container">
        <div class="nav">
            <a href="remote.html">🚀 Remote Control</a>
            <a href="status.php">📊 Server Status</a>
        </div>
        
        <h1>🚀 Server Monitoring Dashboard</h1>
        
        <div class="status <?php echo $server_status > 0 ? 'running' : 'stopped'; ?>">
            <strong>Status:</strong> <?php echo $server_status > 0 ? '✅ RUNNING' : '❌ STOPPED'; ?>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>⏰ Server Uptime</h3>
                <div class="value"><?php echo $uptime; ?></div>
            </div>
            
            <div class="card">
                <h3>📊 PHP Version</h3>
                <div class="value"><?php echo phpversion(); ?></div>
            </div>
            
            <div class="card">
                <h3>🔌 Server Port</h3>
                <div class="value"><?php echo $_SERVER['SERVER_PORT']; ?></div>
            </div>
            
            <div class="card">
                <h3>📁 Document Root</h3>
                <div class="value" style="font-size: 1em;"><?php echo $_SERVER['DOCUMENT_ROOT']; ?></div>
            </div>
        </div>
        
        <h2>💾 Memory Usage</h2>
        <pre><?php echo $memory; ?></pre>
        
        <h2>💿 Disk Usage</h2>
        <pre><?php echo $disk; ?></pre>
        
        <h2>📝 Recent Error Logs (Last 20 lines)</h2>
        <pre><?php echo htmlspecialchars(implode("\n", $last_lines)); ?></pre>
        
        <div class="timestamp">
            Last updated: <?php echo date('Y-m-d H:i:s'); ?>
        </div>
    </div>
</body>
</html>
EOF

    chmod 644 "$SERVER_ROOT/html/status.php"
    
    print_message "Monitoring dashboard created at /status.php" "$GREEN"
}

# Function to create recovery script
create_recovery() {
    print_message "Creating recovery script for crashes..." "$YELLOW"
    
    # Create recovery script
    cat > "$PREFIX/bin/webserver-recover" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Web Server Recovery Script
# This script attempts to recover the server from any state

LOG_FILE="$HOME/webserver/logs/recovery.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

log "Starting recovery process..."

# Step 1: Kill any stuck processes
log "Cleaning up old processes..."
pkill -f httpd 2>/dev/null
pkill -f webserver-watchdog 2>/dev/null
pkill -f cross-platform-api 2>/dev/null
pkill -f node 2>/dev/null
sleep 2

# Step 2: Check port availability
log "Checking port $SERVER_PORT..."
if netstat -tln | grep ":$SERVER_PORT" > /dev/null; then
    log "Port $SERVER_PORT is in use. Attempting to free..."
    fuser -k $SERVER_PORT/tcp 2>/dev/null
    sleep 2
fi

# Step 3: Check configuration
log "Validating Apache configuration..."
httpd -t 2>> "$LOG_FILE"

# Step 4: Start server
log "Starting server..."
httpd -k start
sleep 3

# Step 5: Start API
log "Starting API server..."
pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api 2>/dev/null
sleep 2

# Step 6: Verify
if pgrep -x "httpd" > /dev/null; then
    log "✅ Server recovered successfully!"
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    log "Web server accessible at: http://$IP:$SERVER_PORT"
    log "Remote control at: http://$IP:$SERVER_PORT/remote.html"
    log "API at: http://$IP:8081"
    
    # Restart watchdog
    nohup webserver-watchdog > /dev/null 2>&1 &
    log "Watchdog restarted"
    
    # Restart keep-alive
    nohup keep-alive > /dev/null 2>&1 &
    log "Keep-alive restarted"
else
    log "❌ Recovery failed. Manual intervention required."
    exit 1
fi

# Step 7: Check logs for errors
tail -20 "$HOME/webserver/logs/error_log" >> "$LOG_FILE"
tail -20 "$HOME/webserver/logs/api.log" >> "$LOG_FILE"

log "Recovery process completed"
EOF

    chmod +x "$PREFIX/bin/webserver-recover"
    
    print_message "Recovery script created!" "$GREEN"
}

# Function to create systemd-like service
create_service_manager() {
    print_message "Creating service manager..." "$YELLOW"
    
    # Create main service script
    cat > "$PREFIX/bin/webserver" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Web Server Service Manager
# Controls all aspects of the persistent web server

VERSION="3.0"
CONFIG_DIR="$HOME/webserver"
LOG_DIR="$CONFIG_DIR/logs"

show_help() {
    cat << HELP
Web Server Service Manager v$VERSION
Usage: webserver <command>

Commands:
    start       - Start the web server and all services
    stop        - Stop the web server and all services
    restart     - Restart all services
    status      - Show status of all components
    enable      - Enable auto-start on boot
    disable     - Disable auto-start on boot
    logs        - View all logs
    monitor     - Open monitoring dashboard
    remote      - Open remote control interface
    recover     - Attempt to recover from crashes
    battery     - Show battery optimization help
    info        - Display server information
    backup      - Create a backup
    watchdog    - Control watchdog service
    tmux        - Use tmux persistent session
    api         - Control API server
    client      - Generate client connection scripts

For more details: webserver help <command>
HELP
}

case $1 in
    start)
        echo "🚀 Starting web server services..."
        
        # Start watchdog
        webserver-service start
        
        # Start API
        pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api 2>/dev/null
        
        # Start tmux session
        webserver-persist start
        
        # Start keep-alive
        nohup keep-alive > /dev/null 2>&1 &
        
        echo "✅ All services started"
        echo "🌐 Remote control: http://$(get_ip_address):$SERVER_PORT/remote.html"
        ;;
    
    stop)
        echo "🛑 Stopping web server services..."
        webserver-service stop
        webserver-persist stop
        pm2 kill 2>/dev/null
        pkill -f keep-alive
        pkill -f cross-platform-api
        echo "✅ All services stopped"
        ;;
    
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    
    status)
        echo "📊 Web Server Status"
        echo "==================="
        webserver-service status
        echo ""
        webserver-persist status
        echo ""
        if pm2 list 2>/dev/null | grep -q "online"; then
            echo "✅ API server is running"
        else
            echo "❌ API server is not running"
        fi
        echo ""
        if pgrep -f keep-alive > /dev/null; then
            echo "✅ Keep-alive is running"
        else
            echo "❌ Keep-alive is not running"
        fi
        ;;
    
    enable)
        echo "📌 Enabling auto-start..."
        setup-termux-boot
        pm2 startup 2>/dev/null
        pm2 save 2>/dev/null
        echo "✅ Auto-start enabled"
        ;;
    
    disable)
        echo "📌 Disabling auto-start..."
        rm -f "$HOME/.termux/boot/start-webserver"
        pm2 unstartup 2>/dev/null
        echo "✅ Auto-start disabled"
        ;;
    
    logs)
        case $2 in
            error)
                tail -f "$LOG_DIR/error_log"
                ;;
            access)
                tail -f "$LOG_DIR/access_log"
                ;;
            watchdog)
                tail -f "$LOG_DIR/watchdog.log"
                ;;
            api)
                tail -f "$LOG_DIR/api.log"
                ;;
            all)
                tail -f "$LOG_DIR"/*.log
                ;;
            *)
                echo "Available logs: error, access, watchdog, api, all"
                ;;
        esac
        ;;
    
    monitor)
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
        echo "Opening monitoring dashboard..."
        echo "Visit: http://$IP:$SERVER_PORT/status.php"
        termux-open-url "http://localhost:$SERVER_PORT/status.php" 2>/dev/null || echo "Open browser to that URL"
        ;;
    
    remote)
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
        echo "Opening remote control interface..."
        echo "Visit: http://$IP:$SERVER_PORT/remote.html"
        termux-open-url "http://localhost:$SERVER_PORT/remote.html" 2>/dev/null || echo "Open browser to that URL"
        echo ""
        echo "📱 From another device on the same network:"
        echo "   http://$IP:$SERVER_PORT/remote.html"
        echo "   API: http://$IP:8081"
        echo "   WebSocket: ws://$IP:8082"
        ;;
    
    recover)
        webserver-recover
        ;;
    
    battery)
        optimize-battery
        ;;
    
    info)
        IP=$(get_ip_address)
        echo "📱 Web Server Information"
        echo "========================"
        echo "Local IP:     $IP"
        echo "Port:         $SERVER_PORT"
        echo "Document Root: $HOME/webserver/html"
        echo "Logs:         $HOME/webserver/logs"
        echo "Remote URL:   http://$IP:$SERVER_PORT/remote.html"
        echo "API URL:      http://$IP:8081"
        echo "WebSocket:    ws://$IP:8082"
        echo "Admin user:   admin"
        echo ""
        echo "Management commands:"
        echo "  webserver status  - Check status"
        echo "  webserver remote  - Open remote control"
        echo "  webserver monitor - Open dashboard"
        echo "  webserver logs    - View logs"
        ;;
    
    backup)
        backup-website
        ;;
    
    watchdog)
        shift
        webserver-service $@
        ;;
    
    tmux)
        shift
        webserver-persist $@
        ;;
    
    api)
        case $2 in
            start)
                pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api
                ;;
            stop)
                pm2 stop cross-platform-api
                ;;
            restart)
                pm2 restart cross-platform-api
                ;;
            logs)
                pm2 logs cross-platform-api
                ;;
            status)
                pm2 status cross-platform-api
                ;;
            *)
                echo "Usage: webserver api {start|stop|restart|logs|status}"
                ;;
        esac
        ;;
    
    client)
        IP=$(get_ip_address)
        echo "📱 Client Connection Information"
        echo "================================"
        echo ""
        echo "Web Interface:"
        echo "  http://$IP:$SERVER_PORT/remote.html"
        echo ""
        echo "API Endpoint:"
        echo "  http://$IP:8081"
        echo ""
        echo "WebSocket:"
        echo "  ws://$IP:8082"
        echo ""
        echo "Python Client:"
        echo "  cd ~/webserver/client"
        echo "  python webdroid_client.py status"
        echo ""
        echo "Node.js Client:"
        echo "  cd ~/webserver/client"
        echo "  node webdroid.js interactive"
        echo ""
        echo "Windows Client:"
        echo "  Copy ~/webserver/client/connect.bat to your PC"
        ;;
    
    help|*)
        show_help
        ;;
esac
EOF

    chmod +x "$PREFIX/bin/webserver"
    
    print_message "Service manager created! Use 'webserver' command" "$GREEN"
}

# Function to create sample website
create_sample_website() {
    print_message "Creating sample website..." "$YELLOW"
    
    # Create index.html
    cat > "$SERVER_ROOT/html/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebDroid - Cross Platform Android Server</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 1200px;
            width: 100%;
            animation: slideIn 0.5s ease-out;
        }
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(-20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        h1 {
            color: #2c3e50;
            text-align: center;
            margin-bottom: 20px;
            font-size: 2.5em;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        .badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
            margin: 5px;
        }
        .badge-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .badge-primary {
            background: #cce5ff;
            color: #004085;
            border: 1px solid #b8daff;
        }
        .badge-warning {
            background: #fff3cd;
            color: #856404;
            border: 1px solid #ffeeba;
        }
        .server-info {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 15px;
            margin: 30px 0;
            text-align: center;
        }
        .server-info h2 {
            color: white;
            margin-bottom: 20px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .info-item {
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .info-label {
            font-size: 0.9em;
            opacity: 0.9;
            margin-bottom: 5px;
        }
        .info-value {
            font-size: 1.3em;
            font-weight: bold;
        }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .feature-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            text-align: center;
            transition: transform 0.3s;
            border: 1px solid #dee2e6;
            cursor: pointer;
        }
        .feature-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        .feature-icon {
            font-size: 3em;
            margin-bottom: 10px;
        }
        .feature-title {
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 1.2em;
        }
        .feature-desc {
            color: #6c757d;
            font-size: 0.9em;
            margin-bottom: 15px;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 25px;
            text-decoration: none;
            font-weight: bold;
            transition: all 0.3s;
            border: none;
            cursor: pointer;
            margin: 5px;
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-primary:hover {
            background: #5a67d8;
            transform: scale(1.05);
        }
        .btn-success {
            background: #48bb78;
            color: white;
        }
        .btn-success:hover {
            background: #38a169;
        }
        .status-indicator {
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 20px 0;
        }
        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        .status-dot.online {
            background: #48bb78;
        }
        @keyframes pulse {
            0% {
                box-shadow: 0 0 0 0 rgba(72, 187, 120, 0.7);
            }
            70% {
                box-shadow: 0 0 0 10px rgba(72, 187, 120, 0);
            }
            100% {
                box-shadow: 0 0 0 0 rgba(72, 187, 120, 0);
            }
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 10px;
            margin: 20px 0;
        }
        .stat {
            text-align: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .stat-number {
            font-size: 1.8em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            font-size: 0.9em;
            color: #6c757d;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #6c757d;
        }
        .commands {
            background: #2d3748;
            color: #e2e8f0;
            padding: 20px;
            border-radius: 10px;
            font-family: 'Courier New', monospace;
            margin: 20px 0;
        }
        .command {
            margin: 10px 0;
        }
        .prompt {
            color: #48bb78;
        }
        .platform-badges {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin: 20px 0;
        }
        .platform-badge {
            background: #f8f9fa;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            border: 1px solid #dee2e6;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="platform-badges">
            <span class="platform-badge">📱 Android</span>
            <span class="platform-badge">💻 Windows</span>
            <span class="platform-badge">🍎 MacOS</span>
            <span class="platform-badge">🐧 Linux</span>
        </div>

        <div class="status-indicator">
            <div class="status-dot online"></div>
            <span class="badge badge-success">24/7 OPERATIONAL</span>
            <span class="badge badge-primary">CROSS-PLATFORM</span>
            <span class="badge badge-warning">REMOTE CONTROL</span>
        </div>

        <h1>🚀 WebDroid</h1>
        <h3 style="text-align: center; color: #6c757d;">Control Your Android Device From Any Platform</h3>
        
        <div class="server-info">
            <h2>⚡ Server Status</h2>
            <div class="stats">
                <div class="stat">
                    <div class="stat-number" id="uptime-days">0</div>
                    <div class="stat-label">Days</div>
                </div>
                <div class="stat">
                    <div class="stat-number" id="uptime-hours">0</div>
                    <div class="stat-label">Hours</div>
                </div>
                <div class="stat">
                    <div class="stat-number" id="uptime-mins">0</div>
                    <div class="stat-label">Minutes</div>
                </div>
                <div class="stat">
                    <div class="stat-number" id="uptime-secs">0</div>
                    <div class="stat-label">Seconds</div>
                </div>
            </div>
            
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Server IP</div>
                    <div class="info-value" id="server-ip"><?php echo gethostbyname(gethostname()); ?></div>
                </div>
                <div class="info-item">
                    <div class="info-label">Port</div>
                    <div class="info-value"><?php echo $_SERVER['SERVER_PORT']; ?></div>
                </div>
                <div class="info-item">
                    <div class="info-label">API Port</div>
                    <div class="info-value">8081</div>
                </div>
                <div class="info-item">
                    <div class="info-label">WebSocket</div>
                    <div class="info-value">8082</div>
                </div>
            </div>
        </div>

        <div class="commands">
            <div class="command"><span class="prompt">$</span> webserver status     # Check server status</div>
            <div class="command"><span class="prompt">$</span> webserver remote    # Open remote control</div>
            <div class="command"><span class="prompt">$</span> webserver monitor   # Open dashboard</div>
            <div class="command"><span class="prompt">$</span> webserver logs      # View server logs</div>
        </div>

        <div class="features">
            <div class="feature-card" onclick="window.location.href='remote.html'">
                <div class="feature-icon">🎮</div>
                <div class="feature-title">Remote Control</div>
                <div class="feature-desc">Full device control from any browser</div>
                <button class="btn btn-primary">Open Remote</button>
            </div>
            
            <div class="feature-card" onclick="window.location.href='status.php'">
                <div class="feature-icon">📊</div>
                <div class="feature-title">Server Status</div>
                <div class="feature-desc">Real-time monitoring and statistics</div>
                <button class="btn btn-primary">View Status</button>
            </div>
            
            <div class="feature-card" onclick="window.location.href='shared/'">
                <div class="feature-icon">📁</div>
                <div class="feature-title">File Manager</div>
                <div class="feature-desc">Access and manage files</div>
                <button class="btn btn-primary">Browse Files</button>
            </div>
            
            <div class="feature-card" onclick="window.location.href='api-docs.html'">
                <div class="feature-icon">🔌</div>
                <div class="feature-title">API Access</div>
                <div class="feature-desc">REST API for programmatic control</div>
                <button class="btn btn-primary">View API</button>
            </div>
        </div>

        <div style="text-align: center;">
            <h3>Connect From Any Device</h3>
            <p style="color: #6c757d; margin: 20px 0;">
                Use the IP address shown above to connect from any device on your network
            </p>
            <a href="remote.html" class="btn btn-success">🎮 Launch Remote Control</a>
            <a href="client-scripts.html" class="btn btn-primary">📦 Download Client Scripts</a>
        </div>

        <div class="footer">
            <p>⚡ Cross-Platform Remote Control • REST API • WebSocket • File Management</p>
            <p style="font-size: 0.9em; margin-top: 10px;">
                <span class="badge badge-primary">Windows Client</span>
                <span class="badge badge-success">Linux Client</span>
                <span class="badge badge-primary">Mac Client</span>
                <span class="badge badge-success">Python API</span>
            </p>
        </div>
    </div>

    <script>
        // Update uptime counter
        let startTime = new Date().getTime();
        
        function updateUptime() {
            let now = new Date().getTime();
            let diff = Math.floor((now - startTime) / 1000);
            
            let days = Math.floor(diff / 86400);
            diff -= days * 86400;
            let hours = Math.floor(diff / 3600);
            diff -= hours * 3600;
            let mins = Math.floor(diff / 60);
            let secs = diff % 60;
            
            document.getElementById('uptime-days').textContent = days;
            document.getElementById('uptime-hours').textContent = hours;
            document.getElementById('uptime-mins').textContent = mins;
            document.getElementById('uptime-secs').textContent = secs;
        }
        
        setInterval(updateUptime, 1000);
        
        // Check server status via API
        setInterval(async function() {
            try {
                const response = await fetch('/api/status');
                if (response.ok) {
                    console.log('Server is healthy');
                }
            } catch (error) {
                console.log('Server check failed:', error);
            }
        }, 30000);
    </script>
</body>
</html>
EOF

    chmod 644 "$SERVER_ROOT/html/index.html"
    
    # Create API docs
    cat > "$SERVER_ROOT/html/api-docs.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>WebDroid API Documentation</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 {
            margin-top: 0;
            border-bottom: 2px solid rgba(255,255,255,0.2);
            padding-bottom: 10px;
        }
        .endpoint {
            background: rgba(0,0,0,0.3);
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .method {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 3px;
            font-weight: bold;
            margin-right: 10px;
        }
        .get { background: #61affe; }
        .post { background: #49cc90; }
        .delete { background: #f93e3e; }
        .path {
            font-family: monospace;
            font-size: 1.2em;
        }
        pre {
            background: #1e1e1e;
            color: #d4d4d4;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        .response {
            background: #2d2d2d;
            padding: 10px;
            border-radius: 5px;
            margin-top: 10px;
        }
        .nav {
            margin-bottom: 20px;
        }
        .nav a {
            color: white;
            text-decoration: none;
            margin-right: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="nav">
            <a href="remote.html">← Back to Remote Control</a>
            <a href="status.php">Server Status</a>
        </div>

        <h1>📚 WebDroid API Documentation</h1>
        <p>Base URL: <code>http://[device-ip]:8081/api</code></p>

        <div class="endpoint">
            <span class="method post">POST</span>
            <span class="path">/auth/login</span>
            <h3>Authenticate</h3>
            <p>Get JWT token for API access</p>
            <pre>
{
    "username": "admin",
    "password": "your-password"
}
            </pre>
            <div class="response">
                <strong>Response:</strong>
                <pre>
{
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": "24h"
}
                </pre>
            </div>
        </div>

        <div class="endpoint">
            <span class="method get">GET</span>
            <span class="path">/status</span>
            <h3>Server Status</h3>
            <p>Get current server and system status</p>
            <div class="response">
                <strong>Response:</strong>
                <pre>
{
    "server": {
        "status": "running",
        "uptime": 3600,
        "network": ["192.168.1.100"]
    },
    "system": {
        "cpu": 25,
        "memory": {
            "percent": 45
        }
    }
}
                </pre>
            </div>
        </div>

        <div class="endpoint">
            <span class="method post">POST</span>
            <span class="path">/service/{action}</span>
            <h3>Control Services</h3>
            <p>Start, stop, or restart services</p>
            <pre>
{
    "service": "webserver"
}
            </pre>
            <div class="response">
                <strong>Response:</strong>
                <pre>
{
    "message": "webserver started successfully"
}
                </pre>
            </div>
        </div>

        <div class="endpoint">
            <span class="method get">GET</span>
            <span class="path">/files/{path}</span>
            <h3>List Files</h3>
            <p>Get directory listing or file content</p>
            <div class="response">
                <strong>Response (directory):</strong>
                <pre>
{
    "files": [
        {
            "name": "index.html",
            "type": "file",
            "size": 1024,
            "modified": "2024-01-01T00:00:00Z"
        }
    ]
}
                </pre>
            </div>
        </div>

        <div class="endpoint">
            <span class="method post">POST</span>
            <span class="path">/files/{path}</span>
            <h3>Save File</h3>
            <p>Create or modify a file</p>
            <pre>
{
    "content": "file content here"
}
            </pre>
        </div>

        <div class="endpoint">
            <span class="method post">POST</span>
            <span class="path">/exec</span>
            <h3>Execute Command</h3>
            <p>Run a command on the device</p>
            <pre>
{
    "command": "ls -la"
}
            </pre>
            <div class="response">
                <strong>Response:</strong>
                <pre>
{
    "stdout": "file1.txt\nfile2.txt",
    "stderr": "",
    "error": null
}
                </pre>
            </div>
        </div>

        <div class="endpoint">
            <span class="method get">GET</span>
            <span class="path">/logs/{type}</span>
            <h3>View Logs</h3>
            <p>Get server logs (types: access, error, api, watchdog)</p>
            <div class="response">
                <strong>Response:</strong>
                <pre>
{
    "type": "error",
    "lines": [
        "[error] client denied by server configuration"
    ]
}
                </pre>
            </div>
        </div>

        <h2>WebSocket API</h2>
        <p>Connect to <code>ws://[device-ip]:8082</code> for real-time updates</p>
        
        <div class="endpoint">
            <h3>Client → Server</h3>
            <pre>
{
    "type": "command",
    "command": "uptime"
}
            </pre>
        </div>

        <div class="endpoint">
            <h3>Server → Client</h3>
            <pre>
{
    "type": "status",
    "status": "running",
    "cpu": 25,
    "memory": 45
}
            </pre>
            <pre>
{
    "type": "command_result",
    "stdout": "10:00:00 up 1 day",
    "stderr": ""
}
            </pre>
        </div>
    </div>
</body>
</html>
EOF

    print_message "Sample website and API docs created!" "$GREEN"
}

# Function to create README
create_readme() {
    cat > "$SERVER_ROOT/README.txt" << EOF
==============================================
WEBDROID - CROSS PLATFORM REMOTE CONTROL
==============================================

SERVER INFORMATION:
------------------
Document Root: $SERVER_ROOT/html
Logs Directory: $SERVER_ROOT/logs
Admin Username: $USERNAME
Admin Password: $PASSWORD
Web Server Port: $SERVER_PORT
API Server Port: 8081
WebSocket Port: 8082

ACCESS URLS:
-----------
• Local:     http://localhost:$SERVER_PORT
• Network:   http://$(get_ip_address):$SERVER_PORT
• Remote:    http://$(get_ip_address):$SERVER_PORT/remote.html
• Status:    http://$(get_ip_address):$SERVER_PORT/status.php
• API Docs:  http://$(get_ip_address):$SERVER_PORT/api-docs.html
• API:       http://$(get_ip_address):8081
• WebSocket: ws://$(get_ip_address):8082

CROSS-PLATFORM FEATURES:
-----------------------
✅ Web-based remote control (any browser)
✅ REST API for programmatic access
✅ WebSocket for real-time updates
✅ File manager with editor
✅ Terminal access
✅ Service control
✅ System monitoring
✅ Client scripts for all platforms

CLIENT SCRIPTS LOCATION:
-----------------------
$SERVER_ROOT/client/

Available clients:
• connect.bat     - Windows batch file
• connect.sh      - Linux/Mac shell script
• webdroid_client.py - Python client
• webdroid.js     - Node.js client
• README.md       - Client documentation

MANAGEMENT COMMANDS:
------------------
webserver status     - Check server status
webserver remote     - Open remote control
webserver monitor    - Open monitoring
webserver logs       - View server logs
webserver api        - Control API server
webserver client     - Show client info
webserver start      - Start all services
webserver stop       - Stop all services
webserver restart    - Restart everything
webserver recover    - Recover from crash
webserver enable     - Enable auto-start
webserver disable    - Disable auto-start

IMPORTANT NOTES:
---------------
1. Keep Termux in recent apps
2. Disable battery optimization
3. Both devices must be on same network
4. Use the IP address shown during install
5. Default credentials saved in password.enc

TROUBLESHOOTING:
---------------
• Can't connect?   - Check IP and network
• Server down?     - Run: webserver recover
• API not working? - Run: webserver api restart
• Battery issues?  - Run: webserver battery

Created: $(date)
==============================================
EOF

    print_message "README created!" "$GREEN"
}

# Function to display summary
display_summary() {
    SERVER_IP=$(get_ip_address)
    
    clear
    print_message "╔══════════════════════════════════════════════════╗" "$PURPLE"
    print_message "║     WEBDROID v3.0 - CROSS PLATFORM CONTROL      ║" "$PURPLE"
    print_message "║         Control Android from Any Device          ║" "$PURPLE"
    print_message "╚══════════════════════════════════════════════════╝" "$PURPLE"
    echo ""
    print_message "✅ Installation Complete! Server is ready for remote control" "$GREEN"
    echo ""
    print_message "📌 SERVER DETAILS:" "$YELLOW"
    print_message "   • Local IP:     $SERVER_IP" "$CYAN"
    print_message "   • Web Port:     $SERVER_PORT" "$CYAN"
    print_message "   • API Port:     8081" "$CYAN"
    print_message "   • WebSocket:    8082" "$CYAN"
    print_message "   • Document Root: $SERVER_ROOT/html" "$CYAN"
    echo ""
    print_message "🔐 ADMIN ACCESS:" "$YELLOW"
    print_message "   • Username:     $USERNAME" "$CYAN"
    print_message "   • Password:     $PASSWORD" "$CYAN"
    echo ""
    print_message "🌐 REMOTE ACCESS URLs:" "$YELLOW"
    print_message "   • Remote Control: http://$SERVER_IP:$SERVER_PORT/remote.html" "$GREEN"
    print_message "   • Server Status:  http://$SERVER_IP:$SERVER_PORT/status.php" "$GREEN"
    print_message "   • API Docs:       http://$SERVER_IP:$SERVER_PORT/api-docs.html" "$GREEN"
    print_message "   • API Endpoint:   http://$SERVER_IP:8081" "$GREEN"
    print_message "   • WebSocket:      ws://$SERVER_IP:8082" "$GREEN"
    echo ""
    print_message "📱 CLIENT SCRIPTS:" "$YELLOW"
    print_message "   • Location: $SERVER_ROOT/client/" "$CYAN"
    print_message "   • Windows:   connect.bat" "$CYAN"
    print_message "   • Linux/Mac: connect.sh" "$CYAN"
    print_message "   • Python:    webdroid_client.py" "$CYAN"
    print_message "   • Node.js:   webdroid.js" "$CYAN"
    echo ""
    print_message "📝 MANAGEMENT COMMANDS:" "$YELLOW"
    print_message "   • webserver remote   - Open remote control" "$CYAN"
    print_message "   • webserver status   - Check all services" "$CYAN"
    print_message "   • webserver api      - Control API server" "$CYAN"
    print_message "   • webserver client   - Show client info" "$CYAN"
    print_message "   • webserver logs     - View all logs" "$CYAN"
    print_message "   • webserver recover  - Recover from crash" "$CYAN"
    echo ""
    print_message "⚠️  IMPORTANT:" "$RED"
    print_message "   1. Run: webserver battery   (optimize battery)" "$YELLOW"
    print_message "   2. Both devices must be on same network" "$YELLOW"
    print_message "   3. Use the IP above to connect from other devices" "$YELLOW"
    echo ""
    print_message "✅ Your Android device is now remotely controllable!" "$GREEN"
    print_message "╔══════════════════════════════════════════════════╗" "$PURPLE"
    print_message "║     CONTROL FROM WINDOWS, MAC, LINUX, OR WEB    ║" "$PURPLE"
    print_message "╚══════════════════════════════════════════════════╝" "$PURPLE"
}

# Function to start services
start_services() {
    print_message "Starting persistent web server services..." "$YELLOW"
    
    # Start watchdog
    webserver-service start 2>/dev/null
    
    # Start API
    pm2 start /data/data/com.termux/files/usr/bin/cross-platform-api 2>/dev/null
    
    # Start keep-alive
    nohup keep-alive > /dev/null 2>&1 &
    
    # Start tmux persistence
    webserver-persist start 2>/dev/null
    
    print_message "✅ All services started!" "$GREEN"
}

# Main installation function
main() {
    # Clear screen
    clear
    
    # Print banner
    echo ""
    figlet -f small "WebDroid v3.0" 2>/dev/null || echo "=== WebDroid - Cross Platform Remote Control ==="
    echo ""
    
    print_message "╔══════════════════════════════════════════════════╗" "$PURPLE"
    print_message "║     WEBDROID - CROSS PLATFORM REMOTE CONTROL    ║" "$PURPLE"
    print_message "║         Control Android from Any Device          ║" "$PURPLE"
    print_message "╚══════════════════════════════════════════════════╝" "$PURPLE"
    echo ""
    
    print_message "This script installs a web server with remote control:" "$YELLOW"
    print_message "✅ Runs 24/7 without stopping" "$GREEN"
    print_message "✅ Remote control from any device with a browser" "$GREEN"
    print_message "✅ REST API for programmatic access" "$GREEN"
    print_message "✅ WebSocket for real-time updates" "$GREEN"
    print_message "✅ File manager with editor" "$GREEN"
    print_message "✅ Terminal access from anywhere" "$GREEN"
    echo ""
    
    # Check storage permission
    check_storage_permission
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to install WebDroid with remote control? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "Installation cancelled." "$RED"
        exit 1
    fi
    echo ""
    
    # Ask for custom port
    read -p "Enter web port (default 8080, use 1024-65535): " custom_port
    if [ ! -z "$custom_port" ] && [ "$custom_port" -ge 1024 ] && [ "$custom_port" -le 65535 ]; then
        SERVER_PORT=$custom_port
    fi
    
    # Ask for custom password
    read -p "Enter admin password (empty = random): " custom_password
    if [ ! -z "$custom_password" ]; then
        PASSWORD=$custom_password
    fi
    
    echo ""
    
    # Installation steps
    print_message "Step 1: Updating system..." "$BLUE"
    update_system
    echo ""
    
    print_message "Step 2: Installing packages..." "$BLUE"
    install_packages
    echo ""
    
    print_message "Step 3: Setting up services..." "$BLUE"
    setup_termux_services
    echo ""
    
    print_message "Step 4: Creating directories..." "$BLUE"
    create_directories
    echo ""
    
    print_message "Step 5: Setting up admin..." "$BLUE"
    set_admin_password
    echo ""
    
    print_message "Step 6: Configuring Apache..." "$BLUE"
    configure_apache
    echo ""
    
    print_message "Step 7: Creating watchdog..." "$BLUE"
    create_watchdog
    echo ""
    
    print_message "Step 8: Setting up boot scripts..." "$BLUE"
    setup_boot_scripts
    echo ""
    
    print_message "Step 9: Creating cross-platform API..." "$BLUE"
    create_cross_platform_api
    echo ""
    
    print_message "Step 10: Creating Python API (backup)..." "$BLUE"
    create_python_api
    echo ""
    
    print_message "Step 11: Creating remote interface..." "$BLUE"
    create_remote_interface
    echo ""
    
    print_message "Step 12: Creating client scripts..." "$BLUE"
    create_client_scripts
    echo ""
    
    print_message "Step 13: Creating persistent scripts..." "$BLUE"
    create_persistent_script
    echo ""
    
    print_message "Step 14: Configuring battery optimization..." "$BLUE"
    configure_battery
    echo ""
    
    print_message "Step 15: Creating monitoring..." "$BLUE"
    create_monitoring
    echo ""
    
    print_message "Step 16: Creating recovery tools..." "$BLUE"
    create_recovery
    echo ""
    
    print_message "Step 17: Creating service manager..." "$BLUE"
    create_service_manager
    echo ""
    
    print_message "Step 18: Creating website..." "$BLUE"
    create_sample_website
    echo ""
    
    print_message "Step 19: Creating documentation..." "$BLUE"
    create_readme
    echo ""
    
    # Save API ports to environment
    echo "export API_PORT=$API_PORT" >> "$HOME/.bashrc"
    echo "export WS_PORT=$WEBSOCKET_PORT" >> "$HOME/.bashrc"
    
    # Display summary
    display_summary
    
    # Ask to start server
    echo ""
    read -p "Do you want to start the server and remote control NOW? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_services
    fi
    
    print_message "" "$NC"
    print_message "🚀 WebDroid is now installed and ready for remote control!" "$GREEN"
    print_message "💡 From any device on your network, open:" "$GREEN"
    print_message "   http://$SERVER_IP:$SERVER_PORT/remote.html" "$CYAN"
    print_message "" "$NC"
    print_message "📝 Use 'webserver' command for management" "$CYAN"
    print_message "" "$NC"
}

# Run main function
main
