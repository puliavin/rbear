# rbear/helpers.sh — Logging, process management, colors, lock, cleanup

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'
C_DIM='\033[0;90m'
C_RESET='\033[0m'

IS_DAEMON=false

ensure_dir() {
    [[ -d "$RBEAR_DIR" ]] || mkdir -p "$RBEAR_DIR"
}

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" >> "$LOG_FILE" 2>/dev/null || true
    $IS_DAEMON || echo "[$ts] $*"
}

die() {
    log "FATAL: $*"
    exit 1
}

require_root() {
    [[ "$(id -u)" -eq 0 ]] || die "This command requires root. Use sudo."
}

require_server() {
    [[ -n "$SSH_IP" ]] || die "SSH_IP is not set. Edit $RBEAR_CONF and set your server address."
}

require_deps() {
    local missing=()

    command -v sshuttle &>/dev/null || missing+=("sshuttle  — VPN tunnel (brew install sshuttle)")
    command -v ssh      &>/dev/null || missing+=("ssh       — server connection (built into macOS)")
    command -v curl     &>/dev/null || missing+=("curl      — IP checking (built into macOS)")
    command -v pfctl    &>/dev/null || missing+=("pfctl     — firewall / kill switch (built into macOS)")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies:"
        echo ""
        for dep in "${missing[@]}"; do
            echo "  • $dep"
        done
        echo ""
        die "Install the missing tools and try again."
    fi
}

flush_dns() {
    log "Flushing DNS cache"
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true
}

process_alive() {
    ps -p "$1" >/dev/null 2>&1
}

read_pid_file() {
    [[ -f "$1" ]] && cat "$1" 2>/dev/null || echo ""
}

cleanup_tmp_files() {
    rm -f "$DAEMON_PID_FILE" "$TUNNEL_PID_FILE" "$PF_CONF" \
          "$PF_WAS_ENABLED" "$PF_TOKEN_FILE"
    rm -rf "$LOCK_DIR"
}

# ── Lock ──

acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        return 0
    fi

    local old_pid
    old_pid="$(read_pid_file "$DAEMON_PID_FILE")"
    if [[ -n "$old_pid" ]] && process_alive "$old_pid"; then
        die "Daemon already running (PID $old_pid)"
    fi

    log "Removing stale lock"
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" || die "Cannot acquire lock"
}

release_lock() {
    rm -rf "$LOCK_DIR"
}
