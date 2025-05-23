#!/bin/bash

set -e

NAMESPACE_LOGGING="logging"
NAMESPACE_SYSTEM="kube-system"

echo "🔍 Validating EFK stack..."

# Check Elasticsearch pod(s)
echo "➡️  Checking Elasticsearch pod(s)..."
kubectl get pods -n $NAMESPACE_LOGGING -l app=elasticsearch

# Check Kibana pod
echo "➡️  Checking Kibana pod..."
kubectl get pods -n $NAMESPACE_LOGGING -l app=kibana

# Check Fluent Bit DaemonSet pods
echo "➡️  Checking Fluent Bit pods..."
kubectl get daemonset fluent-bit -n $NAMESPACE_SYSTEM -o jsonpath='{.status.numberReady} ready / {.status.desiredNumberScheduled} scheduled' && echo

# Show service endpoints
echo "🌐 Services:"
kubectl get svc -n $NAMESPACE_LOGGING

# Optional: port-forward Kibana
echo -e "\n💡 To access Kibana UI:"
echo "minikube service kibana -n $NAMESPACE_LOGGING --url"

echo -e "\n✅ Validation complete. If all pods are Running, your EFK stack is good to go!"
