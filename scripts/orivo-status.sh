#!/bin/bash
set -uo pipefail

# Prints the current orivo pomodoro phase and countdown as JSON:
#   {"visible":true,"code":"W","label":"Work Session","time":"24:59","running":true,"live":true}
# or {"visible":false} when orivo has never run.
#
# Prefers orivo's live IPC socket (~/.local/state/orivo/orivo.sock), which
# reports the true running/paused state — something never persisted to
# store.json. Falls back to the last-saved store.json snapshot (frozen,
# not ticking) when orivo isn't currently open.

sock="$HOME/.local/state/orivo/orivo.sock"
store="$HOME/.local/state/orivo/store.json"
config="$HOME/.config/orivo/config.toml"

phase_fields() {
    # $1 = phase string (work/break/long_break or Work/Break/LongBreak)
    case "$1" in
        [Ww]ork) echo "W|Work Session" ;;
        [Bb]reak) echo "B|Short Break" ;;
        [Ll]ong[Bb]reak | long_break) echo "L|Long Break" ;;
        *) echo "W|Work Session" ;;
    esac
}

format_time() {
    # $1 = remaining milliseconds. Reject anything that isn't a plain
    # integer before it reaches arithmetic below: bash's $(( )) performs
    # command substitution on its operand, so an unvalidated value here
    # (e.g. from a crafted socket response) would be a command injection.
    local ms=$1
    [[ "$ms" =~ ^-?[0-9]+$ ]] || ms=0
    [ "$ms" -lt 0 ] && ms=0
    local total_sec=$((ms / 1000))
    printf "%02d:%02d" $((total_sec / 60)) $((total_sec % 60))
}

# --- Try the live socket first ---
if [ -S "$sock" ] && command -v nc >/dev/null 2>&1; then
    live_json=$(timeout 1 nc -U "$sock" </dev/null 2>/dev/null || true)
    if [ -n "$live_json" ] && echo "$live_json" | jq -e . >/dev/null 2>&1; then
        phase=$(echo "$live_json" | jq -r '.phase')
        label=$(echo "$live_json" | jq -r '.label')
        remaining=$(echo "$live_json" | jq -r '.remaining_millis')
        running=$(echo "$live_json" | jq -r '.is_running')
        IFS='|' read -r code _ <<<"$(phase_fields "$phase")"
        time_str=$(format_time "$remaining")
        jq -n --arg code "$code" --arg label "$label" --arg time "$time_str" \
            --argjson running "$running" \
            '{visible: true, code: $code, label: $label, time: $time, running: $running, live: true}'
        exit 0
    fi
fi

# --- Fall back to the last-saved (frozen) store.json snapshot ---
if [ ! -f "$store" ]; then
    echo '{"visible":false}'
    exit 0
fi

phase=$(jq -r '.timer_cycle_phase // "Work"' "$store")
todo_id=$(jq -r '.timer_todo_id // "none"' "$store")
key="$todo_id"

IFS='|' read -r code label <<<"$(phase_fields "$phase")"

work=25
brk=5
longbrk=15
if [ -f "$config" ]; then
    w=$(grep -m1 -E '^\s*work_duration\s*=' "$config" | grep -oE '[0-9]+' | head -1 || true)
    b=$(grep -m1 -E '^\s*break_duration\s*=' "$config" | grep -oE '[0-9]+' | head -1 || true)
    l=$(grep -m1 -E '^\s*long_break_duration\s*=' "$config" | grep -oE '[0-9]+' | head -1 || true)
    [ -n "${w:-}" ] && work="$w"
    [ -n "${b:-}" ] && brk="$b"
    [ -n "${l:-}" ] && longbrk="$l"
fi

case "$code" in
    W) duration_min=$work ;;
    B) duration_min=$brk ;;
    L) duration_min=$longbrk ;;
    *) duration_min=$work ;;
esac
duration_ms=$((duration_min * 60 * 1000))

remaining_ms=$(jq -r --arg k "$key" '.timer_remaining_millis[$k] // empty' "$store")
[ -z "$remaining_ms" ] && remaining_ms=$duration_ms

time_str=$(format_time "$remaining_ms")

jq -n --arg code "$code" --arg label "$label" --arg time "$time_str" \
    '{visible: true, code: $code, label: $label, time: $time, running: false, live: false}'
