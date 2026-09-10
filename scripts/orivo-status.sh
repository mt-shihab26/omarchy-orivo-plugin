#!/bin/bash
set -uo pipefail

# Prints the current orivo pomodoro phase and countdown as JSON:
#   {"visible":true,"code":"W","label":"Work Session","time":"24:59","running":true,"live":true}
# or {"visible":false} when orivo isn't currently open.
#
# Reads orivo's live IPC socket (~/.local/state/orivo/orivo.sock), which
# only exists while orivo is running and reports the true running/paused
# state — something never persisted to store.json. The widget hides
# whenever that socket isn't reachable, rather than showing a frozen
# snapshot from a closed orivo.

# Put the system paths first so the helpers below resolve to the real tools
# even if something earlier on the inherited PATH shadows them, while still
# falling back to the caller's PATH on distros that put them elsewhere.
export PATH="/usr/bin:/bin:${PATH:-}"

sock="$HOME/.local/state/orivo/orivo.sock"

# Everything below builds its output with jq. Without it there is nothing
# useful to report, so hide the widget rather than emitting broken JSON.
if ! command -v jq >/dev/null 2>&1; then
    echo '{"visible":false}'
    exit 0
fi

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
        # Todo text is free-form: collapse newlines and cap the length so one
        # long todo can't turn the tooltip into a wall of text. Sliced in jq
        # rather than cut(1) because jq counts codepoints, so this can't split
        # a multi-byte character and produce invalid UTF-8.
        todo=$(echo "$live_json" | jq -r '
            (.todo_text // "")
            | gsub("[\\n\\r\\t]"; " ")
            | if length > 80 then .[0:79] + "…" else . end')
        IFS='|' read -r code _ <<<"$(phase_fields "$phase")"
        time_str=$(format_time "$remaining")
        jq -n --arg code "$code" --arg label "$label" --arg time "$time_str" \
            --arg todo "$todo" --argjson running "$running" \
            '{visible: true, code: $code, label: $label, time: $time, todo: $todo, running: $running, live: true}'
        exit 0
    fi
fi

echo '{"visible":false}'
