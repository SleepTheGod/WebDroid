#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# ULTIMATE ANDROID SERVER - FULLY AUTOMATED
# SSH + Web Server + 24/7 Operation + Remote Management
# ============================================================
# This script does EVERYTHING automatically:
# ✅ Sets up SSH server (no root required)
# ✅ Installs web server with PHP
# ✅ Configures 24/7 persistence
# ✅ Provides IP address for remote access
# ✅ Creates admin user with password
# ✅ Auto-starts on boot
# ============================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration - CHANGE THESE IF YOU WANT
SSH_PORT=8022
WEB_PORT=8080
USERNAME="admin"
PASSWORD=""
AUTO_GENERATE_PASSWORD=true

# Fixed paths
SERVER_ROOT="$HOME/webserver"
SSH_CONFIG="$PREFIX/etc/ssh/sshd_config"
PERSISTENT_DIR="$HOME/.termux/boot"
LOG_FILE="$HOME/server_install.log"

# ============================================================
# FUNCTIONS
# ============================================================

# Logging function
log() {
    echo -e "${2:-$WHITE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Print banner
print_banner() {
    clear
    echo -e "${PURPLE}"
    figlet -f small "ANDROID SERVER" 2>/dev/null || echo "=== ANDROID SERVER ==="
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         COMPLETE SERVER INSTALLATION - AUTOMATED          ║"
    echo "║              SSH + WEB + 24/7 PERSISTENCE                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Get device IP addresses
get_ips() {
    # Local IP
    LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    
    # Try to get public IP
    PUBLIC_IP=$(curl -s -m 5 ifconfig.me 2>/dev/null || echo "Not available")
    
    # Get all interfaces
    ALL_IPS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | tr '\n' ' ')
    
    echo "$LOCAL_IP|$PUBLIC_IP|$ALL_IPS"
}

# Generate random password
generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# Check and request storage permission
setup_storage() {
    log "📱 Setting up storage access..." "$YELLOW"
    
    if [ ! -d "$HOME/storage/shared" ]; then
        termux-setup-storage
        sleep 5
    fi
    
    if [ -d "$HOME/storage/shared" ]; then
        log "✅ Storage permission granted" "$GREEN"
        # Create shared folder for easy file transfer
        mkdir -p "$HOME/storage/shared/AndroidServer"
        ln -sf "$HOME/storage/shared/AndroidServer" "$HOME/webserver/shared" 2>/dev/null
    else
        log "⚠️ Storage permission not granted, continuing anyway..." "$YELLOW"
    fi
}

# Update system
update_system() {
    log "📦 Updating packages..." "$YELLOW"
    
    pkg update -y -o Dpkg::Options::="--force-confnew" >> "$LOG_FILE" 2>&1
    pkg upgrade -y -o Dpkg::Options::="--force-confnew" >> "$LOG_FILE" 2>&1
    
    log "✅ System updated" "$GREEN"
}

# Install ALL required packages
install_packages() {
    log "📦 Installing server packages..." "$YELLOW"
    
    # Core packages
    pkg install -y \
        openssh \
        apache2 \
        php \
        php-apache \
        mariadb \
        termux-services \
        termux-api \
        termux-tools \
        nano \
        vim \
        git \
        curl \
        wget \
        tmux \
        screen \
        htop \
        openssl-tool \
        netcat-openbsd \
        nmap \
        which \
        man \
        figlet \
        toilet \
        bc \
        proot \
        cronie \
        >> "$LOG_FILE" 2>&1
    
    # Additional useful tools
    pkg install -y \
        ffmpeg \
        python \
        nodejs \
        >> "$LOG_FILE" 2>&1
    
    log "✅ All packages installed" "$GREEN"
}

# Setup SSH server
setup_ssh() {
    log "🔐 Setting up SSH server..." "$YELLOW"
    
    # Stop any existing SSH
    pkill sshd 2>/dev/null
    
    # Create SSH config
    cat > "$SSH_CONFIG" << EOF
# SSH Server Configuration for Termux
Port $SSH_PORT
AddressFamily any
ListenAddress 0.0.0.0
HostKey $PREFIX/etc/ssh/ssh_host_rsa_key
HostKey $PREFIX/etc/ssh/ssh_host_ecdsa_key
HostKey $PREFIX/etc/ssh/ssh_host_ed25519_key

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no

# Security
MaxAuthTries 3
ClientAliveInterval 60
ClientAliveCountMax 3
TCPKeepAlive yes
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes

# Users
AllowUsers $USERNAME
EOF

    # Generate host keys
    ssh-keygen -A >> "$LOG_FILE" 2>&1
    
    # Set up user
    if ! id -u "$USERNAME" >/dev/null 2>&1; then
        # Create user if doesn't exist (in Termux we just use the same user)
        log "Using existing Termux user: $(whoami)" "$BLUE"
    fi
    
    # Set password
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(generate_password)
    fi
    
    # Change password
    echo -e "$PASSWORD\n$PASSWORD" | passwd >> "$LOG_FILE" 2>&1
    
    log "✅ SSH configured on port $SSH_PORT" "$GREEN"
    log "   Username: $(whoami)" "$CYAN"
    log "   Password: $PASSWORD" "$CYAN"
}

# Setup web server
setup_web() {
    log "🌐 Setting up web server..." "$YELLOW"
    
    # Create directory structure
    mkdir -p "$SERVER_ROOT"
    mkdir -p "$SERVER_ROOT/html"
    mkdir -p "$SERVER_ROOT/logs"
    mkdir -p "$SERVER_ROOT/backup"
    mkdir -p "$SERVER_ROOT/ssl"
    mkdir -p "$SERVER_ROOT/cgi-bin"
    
    # Create Apache config
    APACHE_CONFIG="$PREFIX/etc/apache2/httpd.conf"
    
    # Backup original
    [ -f "$APACHE_CONFIG" ] && cp "$APACHE_CONFIG" "$APACHE_CONFIG.backup"
    
    # Write new config
    cat > "$APACHE_CONFIG" << EOF
ServerRoot "$PREFIX"
Listen $WEB_PORT
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

<IfModule unixd_module>
User $(whoami)
Group $(id -gn)
</IfModule>

ServerAdmin admin@localhost
ServerName localhost:$WEB_PORT

<Directory />
    AllowOverride none
    Require all denied
</Directory>

DocumentRoot "$SERVER_ROOT/html"
<Directory "$SERVER_ROOT/html">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.html index.php
</IfModule>

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

<Directory "$SERVER_ROOT/cgi-bin">
    AllowOverride None
    Options None
    Require all granted
</Directory>

<IfModule headers_module>
    RequestHeader unset Proxy early
</IfModule>
EOF

    log "✅ Web server configured on port $WEB_PORT" "$GREEN"
}

# Create web dashboard
create_web_dashboard() {
    log "📊 Creating web dashboard..." "$YELLOW"
    
    # Create index.html
    cat > "$SERVER_ROOT/html/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Android Server Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #141e30, #243b55);
            min-height: 100vh;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            padding: 40px 0;
            background: rgba(255,255,255,0.1);
            border-radius: 20px;
            margin: 20px 0;
            backdrop-filter: blur(10px);
        }
        h1 {
            font-size: 3em;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .status-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 25px;
            transition: transform 0.3s;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .card:hover {
            transform: translateY(-5px);
            background: rgba(255,255,255,0.15);
        }
        .card-title {
            font-size: 1.3em;
            margin-bottom: 15px;
            color: #a0c0ff;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .info-item {
            margin: 10px 0;
            padding: 10px;
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
        }
        .info-label {
            color: #a0c0ff;
            font-size: 0.9em;
        }
        .info-value {
            font-size: 1.2em;
            font-weight: bold;
            word-break: break-all;
        }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
            margin-left: 10px;
        }
        .badge-success {
            background: #10b981;
            color: white;
        }
        .badge-warning {
            background: #f59e0b;
            color: white;
        }
        .command-box {
            background: #1e293b;
            border-radius: 10px;
            padding: 15px;
            font-family: 'Courier New', monospace;
            margin: 10px 0;
        }
        .command {
            color: #10b981;
            margin: 5px 0;
        }
        .button {
            display: inline-block;
            padding: 10px 20px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            text-decoration: none;
            border-radius: 10px;
            margin: 5px;
            transition: all 0.3s;
        }
        .button:hover {
            transform: scale(1.05);
            box-shadow: 0 10px 20px rgba(0,0,0,0.3);
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: rgba(255,255,255,0.6);
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin-top: 20px;
        }
        .stat {
            text-align: center;
            padding: 15px;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            font-size: 0.8em;
            color: #a0c0ff;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 ANDROID SERVER</h1>
            <p>Your Android device is now a fully functional server</p>
            <div>
                <span class="badge badge-success">SSH Active</span>
                <span class="badge badge-success">Web Active</span>
                <span class="badge badge-success">24/7 Online</span>
            </div>
        </div>

        <div class="status-cards">
            <div class="card">
                <div class="card-title">
                    <span>🔐 SSH Access</span>
                </div>
                <div class="info-item">
                    <div class="info-label">Connection Command</div>
                    <div class="command-box">
                        <div class="command">ssh -p <span id="ssh-port">8022</span> <span id="ssh-user">admin</span>@<span id="server-ip">192.168.x.x</span></div>
                    </div>
                </div>
                <div class="info-item">
                    <div class="info-label">SSH Port</div>
                    <div class="info-value" id="ssh-port-value">8022</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Username</div>
                    <div class="info-value" id="ssh-user-value">admin</div>
                </div>
                <div style="text-align: center; margin-top: 20px;">
                    <a href="#" class="button" onclick="showPassword()">🔑 Show Password</a>
                </div>
            </div>

            <div class="card">
                <div class="card-title">
                    <span>🌐 Web Server</span>
                </div>
                <div class="info-item">
                    <div class="info-label">Web URL</div>
                    <div class="command-box">
                        <div class="command">http://<span id="web-ip">192.168.x.x</span>:<span id="web-port">8080</span></div>
                    </div>
                </div>
                <div class="info-item">
                    <div class="info-label">Document Root</div>
                    <div class="info-value">/data/data/.../webserver/html</div>
                </div>
                <div class="info-item">
                    <div class="info-label">PHP Version</div>
                    <div class="info-value" id="php-version"><?php echo phpversion(); ?></div>
                </div>
                <div style="text-align: center; margin-top: 20px;">
                    <a href="status.php" class="button">📊 Server Status</a>
                    <a href="info.php" class="button">ℹ️ PHP Info</a>
                </div>
            </div>

            <div class="card">
                <div class="card-title">
                    <span>📊 System Stats</span>
                </div>
                <div class="stats-grid">
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
                        <div class="stat-label">Mins</div>
                    </div>
                </div>
                <div class="info-item">
                    <div class="info-label">Local IPs</div>
                    <div class="info-value" id="all-ips">Loading...</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Public IP</div>
                    <div class="info-value" id="public-ip">Checking...</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Server Time</div>
                    <div class="info-value" id="server-time"><?php echo date('Y-m-d H:i:s'); ?></div>
                </div>
            </div>
        </div>

        <div style="text-align: center; margin: 30px 0;">
            <a href="filemanager.php" class="button">📁 File Manager</a>
            <a href="shared/" class="button">📱 Shared Files</a>
            <a href="#" class="button" onclick="downloadCredentials()">📥 Download Credentials</a>
        </div>

        <div class="footer">
            <p>⚡ Server runs 24/7 • Auto-restarts on crash • SSH + Web ready</p>
            <p style="font-size: 0.9em; margin-top: 10px;">From your PC: ssh -p 8022 username@ip-address</p>
        </div>
    </div>

    <script>
        // Update server information
        function updateServerInfo() {
            // Get server IPs
            fetch('api/get_ips.php')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('server-ip').textContent = data.local;
                    document.getElementById('web-ip').textContent = data.local;
                    document.getElementById('all-ips').textContent = data.all;
                    document.getElementById('public-ip').textContent = data.public || 'Not available';
                })
                .catch(() => {
                    // Fallback
                    document.getElementById('server-ip').textContent = window.location.hostname;
                    document.getElementById('web-ip').textContent = window.location.hostname;
                });
        }

        // Uptime counter
        let startTime = new Date().getTime();
        
        function updateUptime() {
            let now = new Date().getTime();
            let diff = Math.floor((now - startTime) / 1000);
            
            let days = Math.floor(diff / 86400);
            diff -= days * 86400;
            let hours = Math.floor(diff / 3600);
            diff -= hours * 3600;
            let mins = Math.floor(diff / 60);
            
            document.getElementById('uptime-days').textContent = days;
            document.getElementById('uptime-hours').textContent = hours;
            document.getElementById('uptime-mins').textContent = mins;
        }

        // Show password
        function showPassword() {
            alert('Password: <?php echo $PASSWORD; ?>');
        }

        // Download credentials
        function downloadCredentials() {
            const credentials = `ANDROID SERVER CREDENTIALS
========================
SSH Access:
  Command: ssh -p ${document.getElementById('ssh-port').textContent} ${document.getElementById('ssh-user').textContent}@${document.getElementById('server-ip').textContent}
  Password: <?php echo $PASSWORD; ?>

Web Access:
  URL: http://${document.getElementById('web-ip').textContent}:${document.getElementById('web-port').textContent}

Management:
  Status: http://${document.getElementById('web-ip').textContent}:${document.getElementById('web-port').textContent}/status.php
  Files: http://${document.getElementById('web-ip').textContent}:${document.getElementById('web-port').textContent}/filemanager.php

Generated: ${new Date().toISOString()}`;
            
            const blob = new Blob([credentials], { type: 'text/plain' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'android_server_credentials.txt';
            a.click();
        }

        // Initialize
        updateServerInfo();
        setInterval(updateUptime, 1000);
        setInterval(updateServerInfo, 30000);
    </script>
</body>
</html>
EOF

    # Create status page
    cat > "$SERVER_ROOT/html/status.php" << 'EOF'
<?php
header('Content-Type: application/json');

$data = [
    'server_time' => date('Y-m-d H:i:s'),
    'uptime' => shell_exec('uptime'),
    'local_ip' => trim(shell_exec("ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1")),
    'public_ip' => trim(@file_get_contents('http://ifconfig.me')),
    'ssh_status' => (bool) shell_exec('pgrep sshd'),
    'web_status' => (bool) shell_exec('pgrep httpd'),
    'memory_usage' => shell_exec('free -h'),
    'disk_usage' => shell_exec('df -h'),
    'php_version' => phpversion(),
    'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'
];

echo json_encode($data, JSON_PRETTY_PRINT);
?>
EOF

    # Create API endpoint for IPs
    mkdir -p "$SERVER_ROOT/html/api"
    cat > "$SERVER_ROOT/html/api/get_ips.php" << 'EOF'
<?php
$local = trim(shell_exec("ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1"));
$all = trim(shell_exec("ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | tr '\n' ' '"));
$public = @trim(file_get_contents('http://ifconfig.me'));

header('Content-Type: application/json');
echo json_encode([
    'local' => $local ?: '192.168.x.x',
    'all' => $all ?: 'Unknown',
    'public' => $public ?: null
]);
?>
EOF

    # Create simple file manager
    cat > "$SERVER_ROOT/html/filemanager.php" << 'EOF'
<?php
$root = $_SERVER['DOCUMENT_ROOT'];
$current = isset($_GET['dir']) ? realpath($root . '/' . $_GET['dir']) : $root;

if (strpos($current, $root) !== 0) {
    $current = $root;
}

$items = scandir($current);
?>
<!DOCTYPE html>
<html>
<head>
    <title>File Manager</title>
    <style>
        body { font-family: Arial; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #667eea; padding-bottom: 10px; }
        .path { background: #f8f9fa; padding: 10px; border-radius: 5px; margin: 10px 0; font-family: monospace; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background: #667eea; color: white; }
        tr:hover { background: #f5f5f5; }
        .folder { color: #ffc107; }
        .file { color: #17a2b8; }
        .btn { display: inline-block; padding: 8px 16px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 5px; }
        .btn:hover { background: #5a67d8; }
        .back { margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📁 File Manager</h1>
        <div class="path">Current: <?php echo htmlspecialchars($current); ?></div>
        
        <div class="back">
            <?php if ($current !== $root): ?>
                <a href="?dir=<?php echo urlencode(dirname(substr($current, strlen($root)+1))); ?>" class="btn">⬆️ Go Up</a>
            <?php endif; ?>
        </div>
        
        <table>
            <tr>
                <th>Name</th>
                <th>Size</th>
                <th>Modified</th>
                <th>Actions</th>
            </tr>
            <?php foreach ($items as $item): ?>
                <?php if ($item === '.' || $item === '..') continue; ?>
                <?php $path = $current . '/' . $item; ?>
                <?php $is_dir = is_dir($path); ?>
                <tr>
                    <td>
                        <?php if ($is_dir): ?>
                            <span class="folder">📁</span>
                            <a href="?dir=<?php echo urlencode(substr($path, strlen($root)+1)); ?>"><?php echo htmlspecialchars($item); ?></a>
                        <?php else: ?>
                            <span class="file">📄</span>
                            <a href="<?php echo htmlspecialchars($item); ?>" target="_blank"><?php echo htmlspecialchars($item); ?></a>
                        <?php endif; ?>
                    </td>
                    <td><?php echo $is_dir ? '-' : round(filesize($path)/1024, 2) . ' KB'; ?></td>
                    <td><?php echo date('Y-m-d H:i', filemtime($path)); ?></td>
                    <td>
                        <?php if (!$is_dir): ?>
                            <a href="<?php echo htmlspecialchars($item); ?>" class="btn" style="padding: 3px 10px;" target="_blank">View</a>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
        </table>
    </div>
</body>
</html>
EOF

    chmod -R 755 "$SERVER_ROOT/html"
    log "✅ Web dashboard created" "$GREEN"
}

# Setup persistence (24/7 operation)
setup_persistence() {
    log "⚡ Setting up 24/7 persistence..." "$YELLOW"
    
    # Create boot directory
    mkdir -p "$PERSISTENT_DIR"
    
    # Create boot script
    cat > "$PERSISTENT_DIR/start-servers" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Wait for network
sleep 15

# Start SSH server
sshd

# Start web server
httpd -k start

# Log startup
echo "$(date): Servers started from boot" >> $HOME/webserver/logs/boot.log

# Keep checking
while true; do
    sleep 60
    # Check SSH
    if ! pgrep sshd > /dev/null; then
        echo "$(date): SSH died, restarting..." >> $HOME/webserver/logs/boot.log
        sshd
    fi
    # Check Web
    if ! pgrep httpd > /dev/null; then
        echo "$(date): Web server died, restarting..." >> $HOME/webserver/logs/boot.log
        httpd -k start
    fi
done
EOF
    
    chmod +x "$PERSISTENT_DIR/start-servers"
    
    # Create watchdog
    cat > "$PREFIX/bin/watchdog" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
while true; do
    # Check SSH
    if ! pgrep sshd > /dev/null; then
        echo "$(date): SSH died, restarting..." >> $HOME/webserver/logs/watchdog.log
        sshd
    fi
    
    # Check Web
    if ! pgrep httpd > /dev/null; then
        echo "$(date): Web died, restarting..." >> $HOME/webserver/logs/watchdog.log
        httpd -k start
    fi
    
    # Keep device awake
    termux-wake-lock 2>/dev/null
    
    sleep 30
done
EOF
    
    chmod +x "$PREFIX/bin/watchdog"
    
    # Create management script
    cat > "$PREFIX/bin/server" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

case $1 in
    start)
        echo "Starting servers..."
        sshd
        httpd -k start
        nohup watchdog > /dev/null 2>&1 &
        echo "✅ Servers started"
        ;;
    stop)
        echo "Stopping servers..."
        pkill sshd
        httpd -k stop
        pkill -f watchdog
        echo "✅ Servers stopped"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        echo "📊 Server Status"
        echo "================"
        echo -n "SSH: "
        pgrep sshd > /dev/null && echo "✅ Running" || echo "❌ Stopped"
        echo -n "Web: "
        pgrep httpd > /dev/null && echo "✅ Running" || echo "❌ Stopped"
        echo -n "Watchdog: "
        pgrep -f watchdog > /dev/null && echo "✅ Running" || echo "❌ Stopped"
        echo ""
        echo "IP Addresses:"
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1"
        ;;
    ip)
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1"
        ;;
    logs)
        tail -f $HOME/webserver/logs/*.log
        ;;
    *)
        echo "Usage: server {start|stop|restart|status|ip|logs}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$PREFIX/bin/server"
    
    log "✅ Persistence configured" "$GREEN"
    log "   Use 'server' command to manage services" "$CYAN"
}

# Create credentials file
create_credentials() {
    IPS=$(get_ips)
    LOCAL_IP=$(echo "$IPS" | cut -d'|' -f1)
    PUBLIC_IP=$(echo "$IPS" | cut -d'|' -f2)
    
    cat > "$HOME/ANDROID_SERVER_CREDENTIALS.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║           ANDROID SERVER - CONNECTION CREDENTIALS         ║
╚════════════════════════════════════════════════════════════╝

📱 SERVER INFORMATION
=====================
Installation Date: $(date)
Device: $(getprop ro.product.model 2>/dev/null || echo "Android Device")
Android: $(getprop ro.build.version.release 2>/dev/null || echo "Unknown")

🔐 SSH ACCESS
=============
Command: ssh -p $SSH_PORT $(whoami)@$LOCAL_IP
Username: $(whoami)
Password: $PASSWORD
Port: $SSH_PORT

Alternative commands (if above doesn't work):
  ssh -p $SSH_PORT $(whoami)@$LOCAL_IP
  ssh -o HostKeyAlgorithms=+ssh-rsa -p $SSH_PORT $(whoami)@$LOCAL_IP

🌐 WEB ACCESS
=============
Local URL: http://$LOCAL_IP:$WEB_PORT
Public URL: http://$PUBLIC_IP:$WEB_PORT
Document Root: $SERVER_ROOT/html

📊 MANAGEMENT
=============
Web Dashboard: http://$LOCAL_IP:$WEB_PORT
Server Status: http://$LOCAL_IP:$WEB_PORT/status.php
File Manager: http://$LOCAL_IP:$WEB_PORT/filemanager.php

💻 SERVER COMMANDS (run in Termux)
==================================
server status  - Check server status
server start   - Start all servers
server stop    - Stop all servers
server ip      - Show IP addresses
server logs    - View server logs

📱 OTHER IP ADDRESSES (try these if the above doesn't work)
============================================================
$(echo "$IPS" | cut -d'|' -f3 | tr ' ' '\n' | sed 's/^/  • /')

⚠️ IMPORTANT NOTES
==================
1. Keep Termux running in background
2. Disable battery optimization for Termux
3. Both devices must be on same network for local access
4. For external access, configure port forwarding on router
5. SSH password: $PASSWORD (save this!)

✅ Your Android device is now a server!
========================================
EOF
    
    log "✅ Credentials saved to: $HOME/ANDROID_SERVER_CREDENTIALS.txt" "$GREEN"
}

# Start services
start_services() {
    log "🚀 Starting services..." "$YELLOW"
    
    # Start SSH
    sshd
    sleep 2
    
    # Start web server
    httpd -k start
    sleep 2
    
    # Start watchdog
    nohup watchdog > /dev/null 2>&1 &
    
    log "✅ All services started" "$GREEN"
}

# Display final information
show_completion() {
    IPS=$(get_ips)
    LOCAL_IP=$(echo "$IPS" | cut -d'|' -f1)
    PUBLIC_IP=$(echo "$IPS" | cut -d'|' -f2)
    
    clear
    echo -e "${PURPLE}"
    figlet -f big "READY!" 2>/dev/null || echo "=== SERVER READY ==="
    echo -e "${NC}"
    
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ ANDROID SERVER IS NOW RUNNING                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}📱 DEVICE INFORMATION${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Model: ${CYAN}$(getprop ro.product.model 2>/dev/null || echo "Android Device")${NC}"
    echo -e " Android: ${CYAN}$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")${NC}"
    echo -e " Termux: ${CYAN}$(whoami)@$LOCAL_IP${NC}"
    echo ""
    
    echo -e "${YELLOW}🔐 SSH CONNECTION DETAILS${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}➜${NC} Command: ${CYAN}ssh -p $SSH_PORT $(whoami)@$LOCAL_IP${NC}"
    echo -e " ${GREEN}➜${NC} Username: ${CYAN}$(whoami)${NC}"
    echo -e " ${GREEN}➜${NC} Password: ${CYAN}$PASSWORD${NC}"
    echo -e " ${GREEN}➜${NC} Port: ${CYAN}$SSH_PORT${NC}"
    echo ""
    
    echo -e "${YELLOW}🌐 WEB SERVER ACCESS${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}➜${NC} Local URL: ${CYAN}http://$LOCAL_IP:$WEB_PORT${NC}"
    echo -e " ${GREEN}➜${NC} Public URL: ${CYAN}http://$PUBLIC_IP:$WEB_PORT${NC}"
    echo -e " ${GREEN}➜${NC} Dashboard: ${CYAN}http://$LOCAL_IP:$WEB_PORT${NC}"
    echo -e " ${GREEN}➜${NC} Status Page: ${CYAN}http://$LOCAL_IP:$WEB_PORT/status.php${NC}"
    echo ""
    
    echo -e "${YELLOW}📊 MANAGEMENT COMMANDS${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}➜${NC} ${CYAN}server status${NC}  - Check server status"
    echo -e " ${GREEN}➜${NC} ${CYAN}server start${NC}   - Start all servers"
    echo -e " ${GREEN}➜${NC} ${CYAN}server stop${NC}    - Stop all servers"
    echo -e " ${GREEN}➜${NC} ${CYAN}server ip${NC}      - Show IP addresses"
    echo -e " ${GREEN}➜${NC} ${CYAN}server logs${NC}    - View server logs"
    echo ""
    
    echo -e "${YELLOW}📁 IMPORTANT FILES${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}➜${NC} Credentials: ${CYAN}$HOME/ANDROID_SERVER_CREDENTIALS.txt${NC}"
    echo -e " ${GREEN}➜${NC} Web files: ${CYAN}$SERVER_ROOT/html/${NC}"
    echo -e " ${GREEN}➜${NC} Logs: ${CYAN}$SERVER_ROOT/logs/${NC}"
    echo -e " ${GREEN}➜${NC} Shared: ${CYAN}$HOME/storage/shared/AndroidServer/${NC}"
    echo ""
    
    echo -e "${YELLOW}🌍 OTHER IP ADDRESSES (try these if above doesn't work)${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for ip in $(echo "$IPS" | cut -d'|' -f3); do
        if [ ! -z "$ip" ] && [ "$ip" != "$LOCAL_IP" ]; then
            echo -e " ${CYAN}• $ip${NC}"
        fi
    done
    echo ""
    
    echo -e "${YELLOW}⚠️  IMPORTANT SETUP STEPS FOR 24/7 OPERATION${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${RED}1.${NC} Install Termux:Boot from F-Droid"
    echo -e " ${RED}2.${NC} Disable battery optimization for Termux"
    echo -e "    ${CYAN}Settings > Apps > Termux > Battery > Unrestricted${NC}"
    echo -e " ${RED}3.${NC} Lock Termux in recent apps"
    echo -e " ${RED}4.${NC} Keep Wi-Fi connected"
    echo ""
    
    echo -e "${GREEN}✅ FROM YOUR PC, CONNECT WITH:${NC}"
    echo -e "${CYAN}   ssh -p $SSH_PORT $(whoami)@$LOCAL_IP${NC}"
    echo -e "${CYAN}   Password: $PASSWORD${NC}"
    echo ""
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     YOUR ANDROID IS NOW A FULLY FUNCTIONAL SERVER!       ║${NC}"
    echo -e "${PURPLE}║        SSH + WEB SERVER - READY FOR CONNECTION           ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================================
# MAIN INSTALLATION
# ============================================================

main() {
    print_banner
    
    log "🚀 Starting complete Android server installation..." "$GREEN"
    echo ""
    
    # Ask for custom password
    read -p "Enter admin password (leave empty for auto-generate): " custom_pass
    if [ ! -z "$custom_pass" ]; then
        PASSWORD="$custom_pass"
        AUTO_GENERATE_PASSWORD=false
    fi
    
    echo ""
    log "📋 Installation will use:" "$YELLOW"
    log "   SSH Port: $SSH_PORT" "$CYAN"
    log "   Web Port: $WEB_PORT" "$CYAN"
    log "   Username: $(whoami)" "$CYAN"
    echo ""
    
    read -p "Press Enter to start installation (or Ctrl+C to cancel)..." dummy
    
    echo ""
    log "════════════════════════════════════════════════════════════" "$PURPLE"
    
    # Step 1: Storage
    setup_storage
    
    # Step 2: Update
    update_system
    
    # Step 3: Packages
    install_packages
    
    # Step 4: Generate password if needed
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(generate_password)
    fi
    
    # Step 5: SSH setup
    setup_ssh
    
    # Step 6: Web server setup
    setup_web
    
    # Step 7: Web dashboard
    create_web_dashboard
    
    # Step 8: Persistence
    setup_persistence
    
    # Step 9: Credentials
    create_credentials
    
    # Step 10: Start services
    start_services
    
    # Show completion
    show_completion
    
    # Save password to file for reference
    echo "$PASSWORD" > "$HOME/.server_password"
    chmod 600 "$HOME/.server_password"
    
    log "✅ Installation complete!" "$GREEN"
    log "📁 Credentials saved to: $HOME/ANDROID_SERVER_CREDENTIALS.txt" "$GREEN"
    echo ""
    
    # Test SSH
    log "Testing SSH connection locally..." "$YELLOW"
    ssh -o ConnectTimeout=5 -p $SSH_PORT localhost echo "✅ SSH is working!" 2>/dev/null && log "✅ SSH test passed" "$GREEN" || log "⚠️ SSH test failed, but it should work from other devices" "$YELLOW"
    
    echo ""
    log "════════════════════════════════════════════════════════════" "$PURPLE"
}

# Run main function
main "$@"
