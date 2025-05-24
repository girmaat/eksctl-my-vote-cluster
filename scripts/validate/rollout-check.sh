#!/bin/bash
set -e

DEPLOYMENT=${1:-vote}
NAMESPACE=${2:-default}

echo "🔍 Checking rollout for deployment: $DEPLOYMENT (namespace: $NAMESPACE)"

echo ""
echo "⏳ Watching rollout status..."
kubectl rollout status deployment "$DEPLOYMENT" -n "$NAMESPACE" || {
  echo "❌ Rollout failed or stuck."
  echo "ℹ️  Use the following to view history or rollback:"
  echo "   kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE"
  echo "   kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE"
  exit 1
}

echo ""
echo "✅ Rollout succeeded."

echo ""
echo "📊 Current status:"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
kubectl get pods -l app="$DEPLOYMENT" -n "$NAMESPACE"

echo ""
echo "📜 Last 10 events:"
kubectl describe deployment "$DEPLOYMENT" -n "$NAMESPACE" | tail -n 20
