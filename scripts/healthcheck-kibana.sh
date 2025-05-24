#!/bin/bash

KIBANA_IP=$(minikube ip)
KIBANA_PORT=30561
KIBANA_URL="http://${KIBANA_IP}:${KIBANA_PORT}"

echo "🔍 Testing Kibana at: $KIBANA_URL"

# Check basic connectivity
echo "➡️  Attempting HTTP connection..."
curl -s --connect-timeout 2 "$KIBANA_URL" >/dev/null || {
  echo "❌ Failed to connect to Kibana at $KIBANA_URL"
  exit 1
}

# Check status endpoint
echo "➡️  Checking /api/status..."
STATUS=$(curl -s "$KIBANA_URL/api/status" | jq -r '.status.overall.state')

if [[ "$STATUS" == "green" ]]; then
  echo "✅ Kibana is healthy (status: $STATUS)"
elif [[ "$STATUS" == "yellow" ]]; then
  echo "⚠️  Kibana is up but not fully healthy (status: $STATUS)"
else
  echo "❌ Kibana returned unhealthy status: $STATUS"
fi
