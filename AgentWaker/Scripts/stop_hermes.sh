#!/usr/bin/env bash
set -euo pipefail

TIMEOUT_SECONDS=15
AGENTWAKER_STOP_EXIT_OK=0
AGENTWAKER_STOP_EXIT_GENERAL=1
AGENTWAKER_STOP_EXIT_NOT_FOUND=2
AGENTWAKER_STOP_EXIT_TIMEOUT=3
AGENTWAKER_STOP_EXIT_NOT_RUNNING=4

info()  { printf "[INFO]  %s\n" "$1" >&2; }
warn()  { printf "[WARN]  %s\n" "$1" >&2; }
error() { printf "[ERROR] %s\n" "$1" >&2; }

search_hermes_binary() {
    local candidates=(
        ~/.local/bin/hermes
        /opt/homebrew/bin/hermes
        /usr/local/bin/hermes
        /usr/bin/hermes
    )

    for candidate in "${candidates[@]}"; do
        local expanded="${candidate/#\~/$HOME}"
        if [[ -x "$expanded" ]]; then
            printf "%s" "$expanded"
            return 0
        fi
    done

    if command -v hermes &>/dev/null; then
        command -v hermes
        return 0
    fi

    return 1
}

is_hermes_running() {
    pgrep -f "hermes" &>/dev/null || return 1
    return 0
}

is_hermes_installed() {
    local binary="$1"
    if "$binary" gateway status &>/dev/null; then
        return 0
    fi
    if [[ -f "$HOME/Library/LaunchAgents/com.hermes.gateway.plist" ]] || \
       launchctl list 2>/dev/null | grep -q "hermes"; then
        return 0
    fi
    return 1
}

get_hermes_pids() {
    pgrep -f "hermes" 2>/dev/null | sort -u | grep -v '^$' || true
}

try_graceful_stop() {
    local binary="$1"
    if [[ -x "$binary" ]]; then
        info "Attempting graceful stop via: $binary gateway stop"
        if "$binary" gateway stop &>/dev/null; then
            info "Graceful stop command succeeded"
            return 0
        else
            warn "Graceful stop command failed, falling back to kill"
            return 1
        fi
    fi
    return 1
}

try_uninstall() {
    local binary="$1"
    if is_hermes_installed "$binary"; then
        info "hermes gateway is installed as a system service, uninstalling..."
        if "$binary" gateway uninstall &>/dev/null; then
            info "hermes gateway uninstalled successfully"
        else
            warn "hermes gateway uninstall command failed, continuing anyway"
        fi
        sleep 1
    fi
}

kill_processes() {
    local pids
    pids=$(get_hermes_pids)
    if [[ -z "$pids" ]]; then
        return 0
    fi

    local kill_failed=0
    while IFS= read -r pid; do
        [[ -z "$pid" ]] && continue
        if ! kill "$pid" 2>/dev/null; then
            warn "Failed to send SIGTERM to PID $pid"
            kill_failed=1
        fi
    done <<< "$pids"

    return "$kill_failed"
}

wait_for_exit() {
    local start_time
    start_time=$(date +%s)

    while true; do
        local now
        now=$(date +%s)
        local elapsed=$(( now - start_time ))
        if (( elapsed >= TIMEOUT_SECONDS )); then
            return 1
        fi

        if ! is_hermes_running; then
            return 0
        fi

        sleep 1
    done
}

force_kill_if_needed() {
    local pids
    pids=$(get_hermes_pids)
    [[ -z "$pids" ]] && return 0

    warn "Processes still running after SIGTERM, sending SIGKILL..."
    while IFS= read -r pid; do
        [[ -z "$pid" ]] && continue
        kill -9 "$pid" 2>/dev/null || true
    done <<< "$pids"

    sleep 2

    if is_hermes_running; then
        error "Failed to stop hermes even with SIGKILL"
        return 1
    fi
    warn "force-killed remaining hermes processes"
}

main() {
    if ! is_hermes_running; then
        info "hermes is not running, nothing to stop"
        exit "$AGENTWAKER_STOP_EXIT_NOT_RUNNING"
    fi

    local binary=""
    binary=$(search_hermes_binary) || true

    info "Found hermes binary at: ${binary:-<not found>}"

    if [[ -n "$binary" ]]; then
        try_uninstall "$binary"
        try_graceful_stop "$binary" || true
    fi

    if ! is_hermes_running; then
        info "hermes stopped successfully via graceful command"
        exit "$AGENTWAKER_STOP_EXIT_OK"
    fi

    info "Sending SIGTERM to hermes processes..."
    kill_processes || true

    if wait_for_exit; then
        info "hermes processes terminated gracefully"
        exit "$AGENTWAKER_STOP_EXIT_OK"
    fi

    force_kill_if_needed
    exit "$AGENTWAKER_STOP_EXIT_OK"
}

main "$@"