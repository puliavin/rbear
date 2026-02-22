# rbear/daemon.sh — Daemon lifecycle, start and stop commands

daemon_cleanup() {
    log "Daemon cleanup"
    kill_tunnel
    disable_killswitch
    flush_dns
}

daemon_run() {
    IS_DAEMON=true
    set +e
    trap 'daemon_cleanup; exit 0' TERM INT

    save_pf_state
    enable_killswitch || log "WARNING: initial killswitch failed"
    flush_dns

    local retries=0

    while true; do
        kill_tunnel
        sleep 2

        start_tunnel

        sleep 5
        if process_alive "$TUNNEL_PID"; then
            log "Tunnel UP"
            retries=0
        else
            log "sshuttle died within 5s"
        fi

        wait "$TUNNEL_PID" 2>/dev/null
        log "sshuttle exited (code=$?)"
        rm -f "$TUNNEL_PID_FILE"

        enable_killswitch || log "WARNING: killswitch re-enable failed"

        retries=$((retries + 1))
        if [[ "$MAX_RETRIES" -gt 0 && "$retries" -ge "$MAX_RETRIES" ]]; then
            log "Max retries ($MAX_RETRIES) reached"
            break
        fi

        log "Reconnecting in ${RECONNECT_DELAY}s (attempt $retries)..."
        sleep "$RECONNECT_DELAY"
    done

    daemon_cleanup
}

cmd_start() {
    require_root
    require_deps
    require_server
    ensure_dir
    acquire_lock

    if ! test_ssh; then
        release_lock
        die "SSH connectivity test failed"
    fi

    daemon_run &
    local pid=$!
    disown "$pid"
    echo "$pid" > "$DAEMON_PID_FILE"
    log "Daemon started (PID $pid)"
    echo "rbear started (PID $pid). Logs: $LOG_FILE"
}

cmd_stop() {
    require_root

    local pid
    pid="$(read_pid_file "$DAEMON_PID_FILE")"

    if [[ -n "$pid" ]] && process_alive "$pid"; then
        log "Stopping daemon (PID $pid)"
        kill "$pid" 2>/dev/null || true

        local waited=0
        while process_alive "$pid" && [[ $waited -lt 15 ]]; do
            sleep 1
            waited=$((waited + 1))
        done

        if process_alive "$pid"; then
            log "Force-killing daemon"
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
    fi

    kill_tunnel
    disable_killswitch
    flush_dns
    cleanup_tmp_files
    echo "rbear stopped."
}
