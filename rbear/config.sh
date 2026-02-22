# rbear/config.sh — Configuration management and file paths

RBEAR_CONF="${SCRIPT_DIR}/rbear.conf"

# ── Internal runtime paths ──

RBEAR_DIR="/tmp/rbear"
DAEMON_PID_FILE="${RBEAR_DIR}/rbear.pid"
TUNNEL_PID_FILE="${RBEAR_DIR}/tunnel.pid"
LOCK_DIR="${RBEAR_DIR}/rbear.lock"
LOG_FILE="${RBEAR_DIR}/rbear.log"
PF_CONF="${RBEAR_DIR}/pf.conf"
PF_WAS_ENABLED="${RBEAR_DIR}/pf-was-enabled"
PF_TOKEN_FILE="${RBEAR_DIR}/pf-token"
ANCHOR_NAME="rbear"

# ── User config defaults (overridden by rbear.conf) ──

SSH_IP=""
SSH_PORT="22"
SSH_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"
RECONNECT_DELAY="3"
MAX_RETRIES="0"

# ── Config file operations ──

load_config() {
    if [[ -f "$RBEAR_CONF" ]]; then
        source "$RBEAR_CONF"
    fi
}

require_config() {
    if [[ ! -f "$RBEAR_CONF" ]]; then
        echo "Error: config file not found: $RBEAR_CONF"
        echo ""
        echo "Run '$0 configure' to create it."
        exit 1
    fi
    load_config
}

cmd_configure() {
    if [[ -f "$RBEAR_CONF" ]]; then
        read -rp "Config already exists: $RBEAR_CONF. Overwrite? [y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }
    fi

    cat > "$RBEAR_CONF" <<'CONF'
# rbear.conf — rbear VPN configuration
#
# Edit the values below to match your server setup.
# This file is sourced by rbear.sh on startup.

# IP address of your VPN server (required)
# All traffic will be routed through this server via sshuttle
SSH_IP=""

# SSH port on the VPN server
SSH_PORT="22"

# SSH user for connecting to the VPN server
SSH_USER="root"

# Path to SSH private key for authentication
SSH_KEY="$HOME/.ssh/id_rsa"

# Delay in seconds between reconnection attempts
RECONNECT_DELAY="3"

# Maximum number of reconnection attempts (0 = unlimited)
MAX_RETRIES="0"
CONF

    echo "Config created: $RBEAR_CONF"
    echo ""
    echo "Edit it with your server details, then run:"
    echo "  sudo $0 start"
}
