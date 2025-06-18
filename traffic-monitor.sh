#!/bin/bash

LOG_DIR="/var/log/netadminplus-ssh"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
OUTPUT_FILE="$LOG_DIR/$TIMESTAMP.log"

cleanup_existing_process() {
    local existing_pid
    existing_pid=$(pgrep nethogs)
    if [ -n "$existing_pid" ]; then
        kill "$existing_pid" 2>/dev/null
    fi
}

start_traffic_monitoring() {
    mkdir -p "$LOG_DIR"
    cleanup_existing_process
    nohup /usr/sbin/nethogs -t -a 2>&1 | grep 'sshd:' > "$OUTPUT_FILE" 2>&1 &
}

start_traffic_monitoring