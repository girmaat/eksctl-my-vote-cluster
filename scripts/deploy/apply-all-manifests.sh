#!/bin/bash

set -e

echo "==================================================================="
echo "🧩 STEP 1: Selectively apply environment-specific folders (e.g., EKS)"
echo "==================================================================="

# Prompt before applying EKS metrics
if [ -d "manifests/metrics/eks" ]; then
  read -p "❓ Do you want to apply EKS-specific metrics configs (manifests/metrics/eks)? [y/N]: " confirm_eks
  if [[ "$confirm_eks" =~ ^[Yy]$ ]]; then
    echo "✅ Applying EKS metrics manifests..."
    kubectl apply -f manifests/metrics/eks/ --recursive
  else
    echo "⏭️  Skipping EKS metrics manifests."
  fi
fi

echo ""
echo "==================================================================="
echo "🔧 STEP 2: Ensure required Kubernetes namespaces exist"
echo "==================================================================="

kubectl get namespace logging >/dev/null 2>&1 || { echo "📁 Creating namespace: logging"; kubectl create namespace logging; }
kubectl get namespace kube-system >/dev/null 2>&1 || echo "ℹ️ Namespace 'kube-system' is built-in and already exists."

echo ""
echo "==================================================================="
echo "📦 STEP 3: Applying all manifests under ./manifests recursively"
echo "==================================================================="

kubectl apply -f manifests/ --recursive

echo ""
echo "==================================================================="
echo "🔄 STEP 4: Restarting critical Deployments to pick up new image versions"
echo "==================================================================="

declare -a DEPLOYMENTS=("vote" "result" "worker" "kibana")

for deploy in "${DEPLOYMENTS[@]}"; do
  echo "🔁 Attempting to restart deployment '$deploy'..."
  kubectl rollout restart deployment "$deploy" 2>/dev/null || echo "⚠️  Deployment '$deploy' not found or not in current namespace — skipping."
done

echo ""
echo "=================================================================="
echo "📊 STEP 5: Status Summary — Log Stack Components"
echo "=================================================================="

echo "📥 Elasticsearch Pods (namespace: logging):"
kubectl get pods -n logging -l app=elasticsearch

echo ""
echo "📊 Kibana Pod (namespace: logging):"
kubectl get pods -n logging -l app=kibana

echo ""
echo "📤 Fluent Bit Pods (namespace: kube-system):"
kubectl get pods -n kube-system -l name=fluent-bit

echo ""
echo "🌐 Services in 'logging' namespace:"
kubectl get svc -n logging

echo ""
echo "🎉 All done! Your full EFK stack (and optional metrics) has been applied successfully."
echo "💡 Use 'kubectl logs' or Kibana UI to inspect logs. Run validate-efk.sh to verify health."
