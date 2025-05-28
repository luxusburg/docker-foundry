#!/bin/bash
# foundry-wrapper.sh

# Location of server executable
SERVER_EXE="$server_files/FoundryDedicatedServer.exe"

cleanup() {
    echo "Received shutdown signal, stopping Foundry server..."
    
    # Send SIGTERM to wine process
    kill -TERM "$wine_pid" 2>/dev/null
    
    # Wait for process to exit (with timeout)
    wait_timeout=30
    while kill -0 "$wine_pid" 2>/dev/null && [ $wait_timeout -gt 0 ]; do
        sleep 1
        ((wait_timeout--))
    done
    
    # Force kill if still running
    if kill -0 "$wine_pid" 2>/dev/null; then
        echo "Server did not shutdown gracefully, forcing exit..."
        kill -KILL "$wine_pid" 2>/dev/null
    fi
    
    echo "Server shutdown complete"
    exit 0
}

# Trap signals
trap cleanup SIGINT SIGTERM

# Start Xvfb and Wine
echo "Starting Foundry Dedicated Server via Xvfb and Wine"
xvfb-run wine "$SERVER_EXE" -log 2>&1 &
wine_pid=$!

# Wait for the process to complete
wait "$wine_pid"

# Handle unexpected exits
if [ $? -ne 0 ]; then
    echo "Server process exited unexpectedly"
    exit 1
fi
