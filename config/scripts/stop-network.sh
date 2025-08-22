#!/bin/bash

echo "Stopping Canton Network..."

CANTON_PID=$(pgrep -f "com.digitalasset.canton.CantonCommunityApp")

if [ -n "$CANTON_PID" ]; then
    echo "Found Canton process with PID: $CANTON_PID"
    echo "Sending SIGTERM to Canton process..."
    kill -TERM $CANTON_PID
    
    echo "Waiting for Canton to shutdown gracefully..."
    for i in {1..30}; do
        if ! kill -0 $CANTON_PID 2>/dev/null; then
            echo "Canton process stopped gracefully"
            break
        fi
        sleep 1
        echo -n "."
    done
    
    if kill -0 $CANTON_PID 2>/dev/null; then
        echo ""
        echo "Canton did not stop gracefully, forcing shutdown..."
        kill -KILL $CANTON_PID
        sleep 2
        
        if kill -0 $CANTON_PID 2>/dev/null; then
            echo "ERROR: Failed to stop Canton process"
            exit 1
        else
            echo "Canton process forcefully terminated"
        fi
    fi
else
    echo "No Canton process found running"
fi

echo "Checking if network ports are released..."
LISTENING_PORTS=$(netstat -tlnp | grep -E ':(5001|5002|5018|5021|8090|8091)' | wc -l)
if [ "$LISTENING_PORTS" -eq 0 ]; then
    echo "All Canton network ports are released"
else
    echo "Warning: Some Canton ports may still be in use"
    netstat -tlnp | grep -E ':(5001|5002|5018|5021|8090|8091)'
fi

echo "Canton network stopped successfully"