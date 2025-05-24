#!/bin/bash
set -e

# === USAGE ===
# ./scripts/rollout-check.sh vote
# ./scripts/rollout-check.sh worker default


# === INPUTS ===
DEPLOYMENT_NAME=$1
CONTAINER_NAME=$2
NEW_IMAGE=$3
NAMESPACE=${4:-default}
REPLICAS_CANARY=${5:-1}

if [[ -z "$DEPLOYMENT_NAME" || -z "$CONTAINER_NAME" || -z "$NEW_IMAGE" ]]; then
  echo "❌ Usage: $0 <deployment-name> <container-name> <new-image> [namespace] [replicas]"
  exit 1
fi

echo "🚀 Starting Canary Deployment for $DEPLOYMENT_NAME in namespace '$NAMESPACE'..."

# Step 1: Scale down existing deployment (optional but safe)
echo "🔧 Scaling down current deployment (optional, isolates canary test)..."
kubectl scale deployment $DEPLOYMENT_NAME --replicas=0 --namespace $NAMESPACE

# Step 2: Apply new image
echo "📦 Updating image: $CONTAINER_NAME → $NEW_IMAGE"
kubectl set image deployment/$DEPLOYMENT_NAME $CONTAINER_NAME=$NEW_IMAGE --namespace $NAMESPACE

# Step 3: Scale canary deployment
echo "📊 Scaling canary deployment to $REPLICAS_CANARY pod(s)..."
kubectl scale deployment $DEPLOYMENT_NAME --replicas=$REPLICAS_CANARY --namespace $NAMESPACE

# Step 4: Wait for canary pod readiness
echo "⏳ Waiting for pod readiness..."
kubectl rollout status deployment/$DEPLOYMENT_NAME --namespace $NAMESPACE

# Step 5: Show pod status and help text
kubectl get pods -l app=$DEPLOYMENT_NAME --namespace $NAMESPACE
kubectl describe deployment/$DEPLOYMENT_NAME --namespace $NAMESPACE

echo ""
echo "✅ Canary deployed: $NEW_IMAGE → $DEPLOYMENT_NAME"
echo ""
echo "🔍 Next steps:"
echo " - Run test queries (e.g., curl, prometheus metrics)"
echo " - Check logs: kubectl logs deploy/$DEPLOYMENT_NAME -n $NAMESPACE"
echo ""
echo "🟢 Promote to full deployment:"
echo "   kubectl scale deployment $DEPLOYMENT_NAME --replicas=3 -n $NAMESPACE"
echo ""
echo "🔴 Rollback if needed:"
echo "   kubectl rollout undo deployment $DEPLOYMENT_NAME -n $NAMESPACE"
