#!/bin/bash

set -e

echo "🔁 Applying all Kubernetes YAML manifests under ./manifests..."

# === Step 1: Confirm applying environment-sensitive folders ===

if [ -d "manifests/metrics/eks" ]; then
  read -p "⚠️  Apply EKS metrics manifests? (manifests/metrics/eks) [y/N]: " confirm_eks
  if [[ "$confirm_eks" =~ ^[Yy]$ ]]; then
    echo "✅ Applying EKS metrics..."
    kubectl apply -f manifests/metrics/eks/ --recursive
  else
    echo "⏩ Skipping EKS metrics"
  fi
fi

# === Step 2: Ensure namespaces exist ===

echo "🔧 Ensuring required namespaces exist..."
kubectl get namespace logging >/dev/null 2>&1 || kubectl create namespace logging
kubectl get namespace kube-system >/dev/null 2>&1 || echo "ℹ️ kube-system already exists (system namespace)"

# === Step 3: Apply all general manifests ===

echo "📦 Applying all other manifests recursively..."
kubectl apply -f manifests/ --recursive

# === Step 4: Automatically restart deployments if images changed ===

echo -e "\n🔄 Restarting deployments to ensure updated images are picked up..."

declare -a DEPLOYMENTS=("vote" "result" "worker" "kibana")

for deploy in "${DEPLOYMENTS[@]}"; do
  echo "🔁 Restarting deployment/$deploy in default/logging namespace..."
  kubectl rollout restart deployment "$deploy" || echo "⚠️  Skipped: $deploy not found"
done

# === Step 5: Summary output ===

echo -e "\n✅ Current state of major components:\n"

echo "📥 Elasticsearch:"
kubectl get pods -n logging -l app=elasticsearch

echo -e "\n📊 Kibana:"
kubectl get pods -n logging -l app=kibana

echo -e "\n📤 Fluent Bit:"
kubectl get pods -n kube-system -l name=fluent-bit

echo -e "\n🌐 Services in 'logging' namespace:"
kubectl get svc -n logging

echo -e "\n🎉 Done. Your stack has been applied and restarted where needed."
