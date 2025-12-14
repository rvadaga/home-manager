#!/usr/bin/env bash

# Configuration
SSH_HOST="${1}"             # SSH server hostname or IP (required)
INTERVAL=900                # Seconds between keep-alive pings (default 900 seconds / 15 mins)
LOG_FILE="$HOME/Library/Logs/ssh-keepalive.log"

if [ -z "$SSH_HOST" ]; then
    echo "Usage: $0 <ssh-host>" >&2
    exit 1
fi

echo "Saving keep-alive logs to $LOG_FILE"
# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check if the SSH process is running
is_connection_active() {
    if pgrep -f "ssh -N -o ServerAliveInterval=60 $SSH_HOST" > /dev/null; then
        return 0  # Connection is active
    else
        return 1  # Connection is not active
    fi
}

# Create a single persistent SSH connection with keep-alive packets
start_ssh_connection() {
    log_message "Starting SSH keep-alive connection to $SSH_HOST"
    ssh -N -o ServerAliveInterval=60 "$SSH_HOST" &
    sleep 20

    if is_connection_active; then
        log_message "SSH keep-alive connection established successfully"
    else
        log_message "Failed to establish SSH keep-alive connection"
    fi
}

# Main loop
main() {
    log_message "SSH keep-alive daemon started"

    while true; do
        if ! is_connection_active; then
            log_message "SSH connection not detected, establishing new connection"
            start_ssh_connection
        else
            log_message "SSH connection is active"
        fi

        sleep "$INTERVAL"
    done
}

# Run the main function
main
