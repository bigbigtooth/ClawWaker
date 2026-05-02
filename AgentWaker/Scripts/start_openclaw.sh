#!/usr/bin/env bash
set -euo pipefail

TIMEOUT_SECONDS=15
AGENTWAKER_START_EXIT_OK=0
AGENTWAKER_START_EXIT_GENERAL=1
AGENTWAKER_START_EXIT_NOT_FOUND=2
AGENTWAKER_START_EXIT_TIMEOUT=3
AGENTWAKER_START_EXIT_ALREADY_RUNNING=4

info()  { printf "[INFO]  %s\n" "$1" >&2; }
warn()  { printf "[WARN]  %s\n" "$1" >&2; }
error() { printf "[ERROR] %s\n" "$1" >&2; }

search_openclaw_binary() {
    local candidates=(
        /opt/homebrew/bin/openclaw
        /usr/local/bin/openclaw
        ~/.local/bin/openclaw
        /usr/bin/openclaw
    )

    for candidate in "${candidates[@]}"; do
        local expanded="${candidate/#\~/$HOME}"
        if [[ -x "$expanded" ]]; then
            printf "%s" "$expanded"
            return 0
        fi
    done

    if command -v openclaw &>/dev/null; then
        command -v openclaw
        return 0
    fi

    return 1
}

is_openclaw_running() {
    pgrep -f "openclaw" &>/dev/null || return 1
    return 0
}

is_openclaw_installed() {
    local binary="$1"
    if "$binary" gateway status &>/dev/null; then
        return 0
    fi
    if [[ -f "$HOME/Library/LaunchAgents/com.openclaw.gateway.plist" ]] || \
       launchctl list 2>/dev/null | grep -q "openclaw"; then
        return 0
    fi
    return 1
}

uninstall_openclaw_service() {
    local binary="$1"
    info "openclaw gateway is installed as a system service, uninstalling..."
    if "$binary" gateway uninstall &>/dev/null; then
        info "openclaw gateway uninstalled successfully"
    else
        warn "openclaw gateway uninstall command failed, continuing anyway"
    fi
    if is_openclaw_running; then
        info "Killing remaining openclaw processes after uninstall..."
        local names=("openclaw" "openclaw-gateway")
        for name in "${names[@]}"; do
            while IFS= read -r pid; do
                [[ -z "$pid" ]] && continue
                kill "$pid" 2>/dev/null || true
            done < <(pgrep -f "openclaw" 2>/dev/null || true)
        done
        sleep 2
    fi
}

main() {
    local binary
    if ! binary=$(search_openclaw_binary); then
        error "openclaw binary not found in PATH or common locations"
        exit "$AGENTWAKER_START_EXIT_NOT_FOUND"
    fi

    info "Found openclaw at: $binary"

    if is_openclaw_installed "$binary"; then
        uninstall_openclaw_service "$binary"
    fi

    if is_openclaw_running; then
        info "openclaw is already running, stopping it first..."
        while IFS= read -r pid; do
            [[ -z "$pid" ]] && continue
            kill "$pid" 2>/dev/null || true
        done < <(pgrep -f "openclaw" 2>/dev/null || true)
        sleep 2
        if is_openclaw_running; then
            warn "openclaw still running after SIGTERM, sending SIGKILL..."
            pkill -9 -f "openclaw" 2>/dev/null || true
            sleep 1
        fi
    fi

    if [[ ! -x "$binary" ]]; then
        error "openclaw binary is not executable: $binary"
        exit "$AGENTWAKER_START_EXIT_NOT_FOUND"
    fi

    info "Starting openclaw..."
    local start_time
    start_time=$(date +%s)

    "$binary" &
    local openclaw_pid=$!

    info "openclaw launched with PID $openclaw_pid, waiting for process to appear..."

    while true; do
        local now
        now=$(date +%s)
        local elapsed=$(( now - start_time ))
        if (( elapsed >= TIMEOUT_SECONDS )); then
            warn "Timeout after ${TIMEOUT_SECONDS}s waiting for openclaw process"
            if kill -0 "$openclaw_pid" 2>/dev/null; then
                kill "$openclaw_pid" 2>/dev/null || true
            fi
            exit "$AGENTWAKER_START_EXIT_TIMEOUT"
        fi

        if is_openclaw_running; then
            info "openclaw process detected after ${elapsed}s"
            exit "$AGENTWAKER_START_EXIT_OK"
        fi

        if ! kill -0 "$openclaw_pid" 2>/dev/null; then
            error "openclaw process exited before being detected by pgrep"
            exit "$AGENTWAKER_START_EXIT_GENERAL"
        fi

        sleep 1
    done
}

main "$@"