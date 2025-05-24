#!/bin/bash

# === CONFIGURATION ===
VM_USER="user"                 # Change to your VM's username
VM_HOST="minikubhost"          # Change to your Minikube VM host (can be IP or DNS)
REMOTE_PORT=5601               # Kibana inside Minikube
LOCAL_PORT=5601                # Default forward to localhost:5601
MAX_PORT_TRIES=10              # How many alternative ports to try

# === FIND AVAILABLE LOCAL PORT ===
echo "🔍 Looking for available local port starting from $LOCAL_PORT..."
port_found=false
for ((i=0; i<MAX_PORT_TRIES; i++)); do
  test_port=$((LOCAL_PORT + i))
  if ! lsof -i TCP:$test_port -s TCP:LISTEN >/dev/null 2>&1; then
    echo "✅ Found available port: $test_port"
    LOCAL_PORT=$test_port
    port_found=true
    break
  fi
done

if ! $port_found; then
  echo "❌ No available local port found for Kibana SSH tunnel."
  exit 1
fi

# === START SSH TUNNEL ===
echo "🌐 Setting up SSH tunnel to $VM_HOST:$REMOTE_PORT → localhost:$LOCAL_PORT"
echo "📦 Press Ctrl+C to stop tunnel once done."
echo ""

ssh -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} ${VM_USER}@${VM_HOST} <<EOF
  echo "🟢 Tunnel is active. Opening Kibana UI..."
  if which xdg-open >/dev/null 2>&1; then
    xdg-open http://localhost:${LOCAL_PORT}
  elif which open >/dev/null 2>&1; then
    open http://localhost:${LOCAL_PORT}
  else
    echo "🔗 Please open this in your browser: http://localhost:${LOCAL_PORT}"
  fi
  bash --login
EOF
