#!/bin/sh

set -u # Treat unset variables as an error.

trap "exit" TERM QUIT INT
trap "kill_autopsy" EXIT

export HOME=/config


log_debug() {
    if is-bool-val-true "${CONTAINER_DEBUG:-0}"; then
        echo "$@"
    fi
}

get_autopsy_pid() {
    PID=UNSET
    if [ -f /config/JD2.lock ]; then
        FUSER_STR="$(fuser /config/JD2.lock 2>/dev/null)"
        if [ $? -eq 0 ]; then
            echo "$FUSER_STR" | awk '{print $1}'
            return
        fi
    fi

    echo "UNSET"
}

is_autopsy_running() {
    [ "$(get_autopsy_pid)" != "UNSET" ]
}

start_autopsy() {
    "/autopsy-${AUTOPSY_VERSION}/bin/autopsy" --nosplash >/config/log/output.log 2>&1 &
}

kill_autopsy() {
    PID="$(get_autopsy_pid)"
    if [ "$PID" != "UNSET" ]; then
        log_debug "terminating Autopsy..."
        kill $PID
        wait $PID
        exit $?
    fi
}

# Start JDownloader.
log_debug "starting Autopsy..."
start_autopsy

# Wait until it dies.
wait $!

TIMEOUT=10

while true
do
    if is_autopsy_running; then
        if [ "$TIMEOUT" -lt 10 ]; then
            log_debug "Autopsy has restarted."
        fi

        # Reset the timeout.
        TIMEOUT=10
    else
        if [ "$TIMEOUT" -eq 10 ]; then
            log_debug "Autopsy exited, checking if it is restarting..."
        elif [ "$TIMEOUT" -eq 0 ]; then
            log_debug "Autopsy not restarting, exiting..."
            break
        fi
        TIMEOUT="$(expr $TIMEOUT - 1)"
    fi
    sleep 1
done
