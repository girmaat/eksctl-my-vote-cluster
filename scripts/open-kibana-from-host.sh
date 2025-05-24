#!/bin/bash

# === Configuration ===
KIBANA_PORT=30561
KIBANA_IP="192.168.49.2"  # Replace this with the IP from `minikube ip` if dynamic

URL="http://${KIBANA_IP}:${KIBANA_PORT}"

echo "🌐 Attempting to open Kibana at: $URL"

# Open in Windows default browser
if command -v xdg-open &> /dev/null; then
  xdg-open "$URL"
elif command -v powershell.exe &> /dev/null; then
  powershell.exe start "$URL"
elif command -v explorer.exe &> /dev/null; then
  explorer.exe "$URL"
elif command -v open &> /dev/null; then
  open "$URL"
else
  echo "🔗 Please open manually: $URL"
fi
