#!/data/data/com.termux/files/usr/bin/bash

# Android Local Web Server Setup Script
# For Termux (No root required) - PERSISTENT SERVER
# Author: Taylor Christian Newsome
# Email: SleepRaps@gmail.com
# Version: 2.0 - Never stops!

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
    pkg install -y apache2 php php-apache mariadb curl wget git nano vim openssh termux-services termux-tools termux-api
    
    # Install persistent server tools
    pkg install -y tmux screen htop nload proot which figlet toilet
    
    # Install autostart packages
    pkg install -y termux-services termux-exec
    
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
    DirectoryIndex index.html index.php
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

# Keep alive settings for better performance
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Timeout settings
Timeout 300
EOF
    
    print_message "Apache configured successfully for Termux!" "$GREEN"
}

# Function to create persistent server script
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
    </style>
</head>
<body>
    <div class="container">
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

# Step 5: Verify
if pgrep -x "httpd" > /dev/null; then
    log "✅ Server recovered successfully!"
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    log "Server accessible at: http://$IP:$SERVER_PORT"
    
    # Restart watchdog
    nohup webserver-watchdog > /dev/null 2>&1 &
    log "Watchdog restarted"
else
    log "❌ Recovery failed. Manual intervention required."
    exit 1
fi

# Step 6: Check logs for errors
tail -20 "$HOME/webserver/logs/error_log" >> "$LOG_FILE"

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

VERSION="2.0"
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
    recover     - Attempt to recover from crashes
    battery     - Show battery optimization help
    info        - Display server information
    backup      - Create a backup
    watchdog    - Control watchdog service
    tmux        - Use tmux persistent session

For more details: webserver help <command>
HELP
}

case $1 in
    start)
        echo "🚀 Starting web server services..."
        
        # Start watchdog
        webserver-service start
        
        # Start tmux session
        webserver-persist start
        
        # Start keep-alive
        nohup keep-alive > /dev/null 2>&1 &
        
        echo "✅ All services started"
        ;;
    
    stop)
        echo "🛑 Stopping web server services..."
        webserver-service stop
        webserver-persist stop
        pkill -f keep-alive
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
        if pgrep -f keep-alive > /dev/null; then
            echo "✅ Keep-alive is running"
        else
            echo "❌ Keep-alive is not running"
        fi
        ;;
    
    enable)
        echo "📌 Enabling auto-start..."
        setup-termux-boot
        echo "✅ Auto-start enabled"
        ;;
    
    disable)
        echo "📌 Disabling auto-start..."
        rm -f "$HOME/.termux/boot/start-webserver"
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
            all)
                tail -f "$LOG_DIR"/*.log
                ;;
            *)
                echo "Available logs: error, access, watchdog, all"
                ;;
        esac
        ;;
    
    monitor)
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
        echo "Opening monitoring dashboard..."
        echo "Visit: http://$IP:$SERVER_PORT/status.php"
        termux-open-url "http://localhost:$SERVER_PORT/status.php" 2>/dev/null || echo "Open browser to that URL"
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
        echo "Access URL:   http://$IP:$SERVER_PORT"
        echo "Admin user:   admin"
        echo ""
        echo "Management commands:"
        echo "  webserver status  - Check status"
        echo "  webserver logs    - View logs"
        echo "  webserver monitor - Open dashboard"
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
    <title>Termux Web Server - 24/7 Operation</title>
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
            max-width: 1000px;
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
    </style>
</head>
<body>
    <div class="container">
        <div class="status-indicator">
            <div class="status-dot online"></div>
            <span class="badge badge-success">24/7 OPERATIONAL</span>
            <span class="badge badge-primary">NO ROOT REQUIRED</span>
            <span class="badge badge-warning">PERSISTENT SERVER</span>
        </div>

        <h1>🚀 Android Web Server</h1>
        <h3 style="text-align: center; color: #6c757d;">Running 24/7 on Termux</h3>
        
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
                    <div class="info-label">PHP Version</div>
                    <div class="info-value"><?php echo phpversion(); ?></div>
                </div>
                <div class="info-item">
                    <div class="info-label">Server Time</div>
                    <div class="info-value" id="server-time"></div>
                </div>
            </div>
        </div>

        <div class="commands">
            <div class="command"><span class="prompt">$</span> webserver status     # Check server status</div>
            <div class="command"><span class="prompt">$</span> webserver monitor   # Open dashboard</div>
            <div class="command"><span class="prompt">$</span> webserver logs      # View server logs</div>
            <div class="command"><span class="prompt">$</span> webserver recover   # Recover from crash</div>
        </div>

        <div class="features">
            <div class="feature-card" onclick="window.location.href='status.php'">
                <div class="feature-icon">📊</div>
                <div class="feature-title">Server Status</div>
                <div class="feature-desc">Real-time monitoring and statistics</div>
                <button class="btn btn-primary">View Dashboard</button>
            </div>
            
            <div class="feature-card" onclick="window.location.href='filemanager.php'">
                <div class="feature-icon">📁</div>
                <div class="feature-title">File Manager</div>
                <div class="feature-desc">Manage your website files</div>
                <button class="btn btn-primary">Browse Files</button>
            </div>
            
            <div class="feature-card" onclick="window.location.href='info.php'">
                <div class="feature-icon">ℹ️</div>
                <div class="feature-title">PHP Info</div>
                <div class="feature-desc">PHP configuration details</div>
                <button class="btn btn-primary">View Info</button>
            </div>
            
            <div class="feature-card" onclick="window.location.href='shared/'">
                <div class="feature-icon">📱</div>
                <div class="feature-title">Shared Storage</div>
                <div class="feature-desc">Access Android files</div>
                <button class="btn btn-primary">Open Folder</button>
            </div>
        </div>

        <div style="text-align: center;">
            <a href="status.php" class="btn btn-success">📊 Server Monitor</a>
            <a href="filemanager.php" class="btn btn-primary">📁 File Manager</a>
        </div>

        <div class="footer">
            <p>⚡ Server runs 24/7 • Auto-restarts on crash • Starts on boot</p>
            <p style="font-size: 0.9em; margin-top: 10px;">
                <span class="badge badge-primary">Watchdog Active</span>
                <span class="badge badge-success">Auto-Recovery</span>
                <span class="badge badge-primary">Boot Service</span>
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
        
        // Update server time
        function updateTime() {
            const now = new Date();
            document.getElementById('server-time').textContent = now.toLocaleString();
        }
        
        setInterval(updateUptime, 1000);
        setInterval(updateTime, 1000);
        
        // Check server status via AJAX every 30 seconds
        setInterval(function() {
            fetch('status.php')
                .then(response => {
                    if (response.ok) {
                        console.log('Server is healthy');
                    }
                })
                .catch(error => {
                    console.log('Server check failed:', error);
                });
        }, 30000);
    </script>
</body>
</html>
EOF

    chmod 644 "$SERVER_ROOT/html/index.html"
    print_message "Sample website created!" "$GREEN"
}

# Function to create README
create_readme() {
    cat > "$SERVER_ROOT/README.txt" << EOF
==============================================
TERMUX WEB SERVER - PERSISTENT OPERATION GUIDE
==============================================

SERVER INFORMATION:
------------------
Document Root: $SERVER_ROOT/html
Logs Directory: $SERVER_ROOT/logs
Admin Username: $USERNAME
Admin Password: $PASSWORD
Server Port: $SERVER_PORT

ACCESS URLS:
-----------
• Local: http://localhost:$SERVER_PORT
• Network: http://$(get_ip_address):$SERVER_PORT
• Status: http://$(get_ip_address):$SERVER_PORT/status.php

PERSISTENT FEATURES:
-------------------
✅ 24/7 Operation
✅ Auto-start on boot
✅ Watchdog monitoring
✅ Crash recovery
✅ Battery optimization helpers
✅ Tmux persistence
✅ Keep-alive service

MANAGEMENT COMMANDS:
------------------
webserver status     - Check server status
webserver start      - Start all services
webserver stop       - Stop all services
webserver restart    - Restart everything
webserver monitor    - Open monitoring dashboard
webserver logs       - View server logs
webserver recover    - Recover from crash
webserver enable     - Enable boot auto-start
webserver disable    - Disable boot auto-start
webserver battery    - Battery optimization help
webserver backup     - Create backup
webserver info       - Display server info

WATCHDOG COMMANDS:
-----------------
webserver watchdog start   - Start watchdog
webserver watchdog stop    - Stop watchdog
webserver watchdog status  - Check watchdog
webserver watchdog logs    - View watchdog logs

TMUX COMMANDS:
-------------
webserver tmux start   - Start tmux session
webserver tmux stop    - Stop tmux session
webserver tmux attach  - Attach to session
webserver tmux status  - Check tmux status

ADDITIONAL TOOLS:
---------------
start-webserver     - Legacy start command
stop-webserver      - Legacy stop command
status-webserver    - Legacy status
backup-website      - Create backup
view-logs           - View server logs
webserver-watchdog  - Watchdog daemon
webserver-service   - Service controller
webserver-persist   - Tmux persistence
webserver-recover   - Recovery tool
keep-alive          - Keep device awake
optimize-battery    - Battery settings

IMPORTANT NOTES:
---------------
1. Keep Termux in recent apps (lock if possible)
2. Disable battery optimization for Termux
3. Add Termux to auto-start whitelist
4. Use Wi-Fi for better stability
5. The server will auto-restart if it crashes
6. Check logs regularly: webserver logs

TROUBLESHOOTING:
---------------
• If server won't start: webserver recover
• If device sleeps: run "keep-alive"
• If battery kills Termux: webserver battery
• If port conflicts: change port in config
• If slow: check resources in monitoring

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
    print_message "║     TERMUX PERSISTENT WEB SERVER v2.0          ║" "$PURPLE"
    print_message "║             24/7 OPERATION READY               ║" "$PURPLE"
    print_message "╚══════════════════════════════════════════════════╝" "$PURPLE"
    echo ""
    print_message "✅ Installation Complete! Server will run 24/7" "$GREEN"
    echo ""
    print_message "📌 SERVER DETAILS:" "$YELLOW"
    print_message "   • Local IP:     $SERVER_IP" "$CYAN"
    print_message "   • Port:         $SERVER_PORT" "$CYAN"
    print_message "   • Document Root: $SERVER_ROOT/html" "$CYAN"
    print_message "   • Logs:         $SERVER_ROOT/logs" "$CYAN"
    echo ""
    print_message "🔐 ADMIN ACCESS:" "$YELLOW"
    print_message "   • Username:     $USERNAME" "$CYAN"
    print_message "   • Password:     $PASSWORD" "$CYAN"
    echo ""
    print_message "🚀 PERSISTENT FEATURES ENABLED:" "$YELLOW"
    print_message "   • ✓ Auto-start on device boot" "$GREEN"
    print_message "   • ✓ Watchdog monitoring (auto-restart on crash)" "$GREEN"
    print_message "   • ✓ Keep-alive service (prevents sleep)" "$GREEN"
    print_message "   • ✓ Crash recovery system" "$GREEN"
    print_message "   • ✓ Tmux persistence" "$GREEN"
    print_message "   • ✓ Battery optimization helpers" "$GREEN"
    echo ""
    print_message "📝 MANAGEMENT COMMANDS:" "$YELLOW"
    print_message "   • webserver status   - Check everything" "$CYAN"
    print_message "   • webserver start    - Start all services" "$CYAN"
    print_message "   • webserver stop     - Stop all services" "$CYAN"
    print_message "   • webserver monitor  - Open dashboard" "$CYAN"
    print_message "   • webserver logs     - View all logs" "$CYAN"
    print_message "   • webserver recover  - Recover from crash" "$CYAN"
    print_message "   • webserver enable   - Enable auto-start" "$CYAN"
    print_message "   • webserver battery  - Battery optimization" "$CYAN"
    echo ""
    print_message "🌐 ACCESS YOUR WEBSITE:" "$YELLOW"
    print_message "   • Local:  http://localhost:$SERVER_PORT" "$GREEN"
    print_message "   • Network: http://$SERVER_IP:$SERVER_PORT" "$GREEN"
    print_message "   • Monitor: http://$SERVER_IP:$SERVER_PORT/status.php" "$GREEN"
    echo ""
    print_message "📱 SHARED STORAGE:" "$YELLOW"
    print_message "   • http://$SERVER_IP:$SERVER_PORT/shared/" "$GREEN"
    echo ""
    print_message "⚠️  CRITICAL SETUP STEPS:" "$RED"
    print_message "   1. Run: webserver battery   (follow instructions)" "$YELLOW"
    print_message "   2. Lock Termux in recent apps" "$YELLOW"
    print_message "   3. Disable battery optimization for Termux" "$YELLOW"
    print_message "   4. Enable auto-start: webserver enable" "$YELLOW"
    echo ""
    print_message "✅ The server will now run 24/7 and auto-recover!" "$GREEN"
    print_message "╔══════════════════════════════════════════════════╗" "$PURPLE"
    print_message "║     SERVER IS PERSISTENT - IT WILL NEVER STOP   ║" "$PURPLE"
    print_message "╚══════════════════════════════════════════════════╝" "$PURPLE"
}

# Function to start services
start_services() {
    print_message "Starting persistent web server services..." "$YELLOW"
    
    # Start watchdog
    webserver-service start 2>/dev/null
    
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
    figlet -f small "24/7 Web Server" 2>/dev/null || echo "=== 24/7 Web Server for Android ==="
    echo ""
    
    print_message "╔══════════════════════════════════════════════════╗" "$PURPLE"
    print_message "║     PERSISTENT WEB SERVER FOR ANDROID           ║" "$PURPLE"
    print_message "║              NEVER STOPS RUNNING                ║" "$PURPLE"
    print_message "╚══════════════════════════════════════════════════╝" "$PURPLE"
    echo ""
    
    print_message "This script installs a web server that:" "$YELLOW"
    print_message "✅ Runs 24/7 without stopping" "$GREEN"
    print_message "✅ Auto-starts when your device boots" "$GREEN"
    print_message "✅ Auto-recovers if it crashes" "$GREEN"
    print_message "✅ Stays alive even when phone sleeps" "$GREEN"
    echo ""
    
    # Check storage permission
    check_storage_permission
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to install the 24/7 web server? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "Installation cancelled." "$RED"
        exit 1
    fi
    echo ""
    
    # Ask for custom port
    read -p "Enter port (default 8080, use 1024-65535): " custom_port
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
    
    print_message "Step 9: Creating persistent scripts..." "$BLUE"
    create_persistent_script
    echo ""
    
    print_message "Step 10: Configuring battery optimization..." "$BLUE"
    configure_battery
    echo ""
    
    print_message "Step 11: Creating monitoring..." "$BLUE"
    create_monitoring
    echo ""
    
    print_message "Step 12: Creating recovery tools..." "$BLUE"
    create_recovery
    echo ""
    
    print_message "Step 13: Creating service manager..." "$BLUE"
    create_service_manager
    echo ""
    
    print_message "Step 14: Creating website..." "$BLUE"
    create_sample_website
    echo ""
    
    print_message "Step 15: Creating documentation..." "$BLUE"
    create_readme
    echo ""
    
    # Display summary
    display_summary
    
    # Ask to start server
    echo ""
    read -p "Do you want to start the persistent server NOW? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_services
    fi
    
    print_message "" "$NC"
    print_message "🚀 The server is now configured to run 24/7!" "$GREEN"
    print_message "💡 It will auto-start on boot and never stop!" "$GREEN"
    print_message "📝 Use 'webserver' command for management" "$CYAN"
    print_message "" "$NC"
}

# Run main function
main
