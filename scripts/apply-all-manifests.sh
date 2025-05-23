#!/bin/bash

set -e

echo "🔁 Applying all Kubernetes YAML manifests under ./manifests..."

# 1. Create required namespaces explicitly if not created via YAML
echo "🔧 Ensuring required namespaces exist..."
kubectl get namespace logging >/dev/null 2>&1 || kubectl create namespace logging
kubectl get namespace kube-system >/dev/null 2>&1 || echo "ℹ️ kube-system already exists (system namespace)"

# 2. Apply all YAMLs recursively
echo "📦 Applying manifests..."
kubectl apply -f manifests/ --recursive

# 3. Show result summaries for major components
echo -e "\n✅ Current state of major components:\n"

echo "📥 Elasticsearch:"
kubectl get pods -n logging -l app=elasticsearch

echo -e "\n📊 Kibana:"
kubectl get pods -n logging -l app=kibana

echo -e "\n📤 Fluent Bit:"
kubectl get pods -n kube-system -l name=fluent-bit

echo -e "\n🌐 Services in 'logging' namespace:"
kubectl get svc -n logging

echo -e "\n✅ Done. Your entire EFK stack (and any app or metrics stack) has been applied."
