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

uninstall_hermes_service() {
    local binary="$1"
    info "hermes gateway is installed as a system service, uninstalling..."
    if "$binary" gateway uninstall &>/dev/null; then
        info "hermes gateway uninstalled successfully"
    else
        warn "hermes gateway uninstall command failed, continuing anyway"
    fi
    if is_hermes_running; then
        info "Killing remaining hermes processes after uninstall..."
        while IFS= read -r pid; do
            [[ -z "$pid" ]] && continue
            kill "$pid" 2>/dev/null || true
        done < <(pgrep -f "hermes" 2>/dev/null || true)
        sleep 2
    fi
}

main() {
    local binary
    if ! binary=$(search_hermes_binary); then
        error "hermes binary not found in PATH or common locations"
        exit "$AGENTWAKER_START_EXIT_NOT_FOUND"
    fi

    info "Found hermes at: $binary"

    if is_hermes_installed "$binary"; then
        uninstall_hermes_service "$binary"
    fi

    if is_hermes_running; then
        info "hermes is already running, stopping it first..."
        while IFS= read -r pid; do
            [[ -z "$pid" ]] && continue
            kill "$pid" 2>/dev/null || true
        done < <(pgrep -f "hermes" 2>/dev/null || true)
        sleep 2
        if is_hermes_running; then
            warn "hermes still running after SIGTERM, sending SIGKILL..."
            pkill -9 -x "hermes" 2>/dev/null || true
            sleep 1
        fi
    fi

    if [[ ! -x "$binary" ]]; then
        error "hermes binary is not executable: $binary"
        exit "$AGENTWAKER_START_EXIT_NOT_FOUND"
    fi

    info "Starting hermes gateway..."

    "$binary" gateway run &
    local hermes_pid=$!

    info "hermes gateway run launched with PID $hermes_pid, waiting for process to appear..."

    local start_time
    start_time=$(date +%s)

    while true; do
        local now
        now=$(date +%s)
        local elapsed=$(( now - start_time ))
        if (( elapsed >= TIMEOUT_SECONDS )); then
            warn "Timeout after ${TIMEOUT_SECONDS}s waiting for hermes process"
            if kill -0 "$hermes_pid" 2>/dev/null; then
                kill "$hermes_pid" 2>/dev/null || true
            fi
            exit "$AGENTWAKER_START_EXIT_TIMEOUT"
        fi

        if is_hermes_running; then
            info "hermes process detected after ${elapsed}s"
            exit "$AGENTWAKER_START_EXIT_OK"
        fi

        if ! kill -0 "$hermes_pid" 2>/dev/null; then
            error "hermes process exited before being detected by pgrep"
            exit "$AGENTWAKER_START_EXIT_GENERAL"
        fi

        sleep 1
    done
}

main "$@"