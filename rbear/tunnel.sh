# rbear/tunnel.sh — sshuttle tunnel and SSH connectivity

test_ssh() {
    log "Testing SSH to ${SSH_USER}@${SSH_IP}:${SSH_PORT}"
    local -a args=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes -p "$SSH_PORT")
    [[ -n "$SSH_KEY" ]] && args+=(-i "$SSH_KEY")

    if ssh "${args[@]}" "${SSH_USER}@${SSH_IP}" "echo ok" >/dev/null 2>&1; then
        log "SSH test passed"
    else
        log "SSH test FAILED"
        return 1
    fi
}

start_tunnel() {
    log "Starting sshuttle"
    local -a args=(--dns --disable-ipv6 -r "${SSH_USER}@${SSH_IP}:${SSH_PORT}")
    local ssh_cmd="ssh -T -x -c aes128-ctr -o Compression=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3"
    [[ -n "$SSH_KEY" ]] && ssh_cmd+=" -i $(printf '%q' "$SSH_KEY")"
    args+=(--ssh-cmd "$ssh_cmd")
    args+=(0/0)

    sshuttle "${args[@]}" < /dev/null >> "$LOG_FILE" 2>&1 &
    TUNNEL_PID=$!
    echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"
    log "sshuttle started (PID $TUNNEL_PID)"
}

kill_tunnel() {
    local pid
    pid="$(read_pid_file "$TUNNEL_PID_FILE")"
    if [[ -n "$pid" ]] && process_alive "$pid"; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$TUNNEL_PID_FILE"

    local pids
    pids="$(pgrep -f '[s]shuttle' 2>/dev/null || echo "")"
    if [[ -n "$pids" ]]; then
        log "Killing sshuttle processes"
        for p in $pids; do kill "$p" 2>/dev/null || true; done

        local waited=0
        while [[ $waited -lt 5 ]]; do
            pids="$(pgrep -f '[s]shuttle' 2>/dev/null || echo "")"
            [[ -z "$pids" ]] && break
            sleep 1
            waited=$((waited + 1))
        done

        pids="$(pgrep -f '[s]shuttle' 2>/dev/null || echo "")"
        if [[ -n "$pids" ]]; then
            log "Force-killing sshuttle"
            for p in $pids; do kill -9 "$p" 2>/dev/null || true; done
            sleep 1
        fi
    fi

    for a in $(pfctl -s Anchors 2>/dev/null | grep -i sshuttle || true); do
        pfctl -a "$a" -F all 2>/dev/null || true
    done
}
