#!/bin/bash

set -e

echo "==================================================================="
echo "⚠️  WARNING: This will DELETE all Kubernetes resources in ./manifests/"
echo "==================================================================="
read -p "❓ Are you sure you want to proceed? This action cannot be undone. [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Cancelled. No resources were deleted."
  exit 1
fi

echo ""
echo "==================================================================="
echo "🧨 STEP 1: Delete all manifest-based resources recursively"
echo "==================================================================="

kubectl delete -f manifests/ --recursive || echo "⚠️ Some resources may not have been found (already deleted)."

echo ""
echo "==================================================================="
echo "🧼 STEP 2: Optionally delete the custom 'logging' namespace"
echo "==================================================================="
read -p "❓ Do you want to delete the entire 'logging' namespace (Elasticsearch, Kibana, etc)? [y/N]: " delete_ns

if [[ "$delete_ns" =~ ^[Yy]$ ]]; then
  echo "🗑️ Deleting namespace: logging"
  kubectl delete namespace logging || echo "⚠️ Namespace 'logging' was already deleted or not found."
else
  echo "⏭️  Skipping namespace deletion."
fi

echo ""
echo "==================================================================="
echo "✅ Clean-up Summary"
echo "==================================================================="

echo "🚫 Resources defined in ./manifests/ have been deleted."
echo "🧹 Remaining namespaces:"
kubectl get namespaces

echo ""
echo "🎉 Destruction process completed. You're now back to a clean cluster state."
