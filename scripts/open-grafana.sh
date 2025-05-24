#!/bin/bash

set -e

# Configuration
NAMESPACE="monitoring"
SERVICE="grafana"
LOCAL_PORT=3000
REMOTE_PORT=3000

echo "🔄 Port-forwarding Grafana from ${NAMESPACE}/${SERVICE}..."
echo "🌐 It will be accessible at: http://localhost:${LOCAL_PORT}"

# Start port-forwarding in the background
kubectl port-forward -n $NAMESPACE svc/$SERVICE $LOCAL_PORT:$REMOTE_PORT > /dev/null 2>&1 &

# Give port-forward time to start
sleep 2

# Try to open the browser (depends on Linux desktop or WSL)
if command -v xdg-open > /dev/null; then
  xdg-open "http://localhost:$LOCAL_PORT"
elif command -v gnome-open > /dev/null; then
  gnome-open "http://localhost:$LOCAL_PORT"
elif command -v open > /dev/null; then
  open "http://localhost:$LOCAL_PORT"
else
  echo "🔗 Please open this URL manually: http://localhost:$LOCAL_PORT"
fi

echo "🟢 Port forward is active. Press Ctrl+C to stop it when you're done."
# Keep script alive so port-forwarding stays up
wait
