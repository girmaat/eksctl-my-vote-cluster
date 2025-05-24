#!/bin/bash
set -e

echo "🔍 Fluent Bit Diagnostics (minikube)"

echo -e "\n1️⃣ Checking if fluent-bit DaemonSet is running..."
kubectl get daemonset fluent-bit -n kube-system

echo -e "\n2️⃣ Checking recent fluent-bit logs..."
LOG_OUTPUT=$(kubectl logs -n kube-system -l name=fluent-bit --tail=30 2>&1)

if echo "$LOG_OUTPUT" | grep -q "parser 'cri' is not registered"; then
  echo "❌ Parser 'cri' is not registered. Likely parser config not loaded."
else
  echo "✅ No parser errors detected."
fi

if echo "$LOG_OUTPUT" | grep -q "Could not open parser configuration file"; then
  echo "❌ Fluent Bit failed to open parser file. Check mountPath + subPath!"
else
  echo "✅ Parser file loaded (no 'could not open' error)."
fi

echo -e "\n3️⃣ Checking if fluent-bit-parsers ConfigMap exists..."
kubectl get configmap fluent-bit-parsers -n kube-system

echo -e "\n4️⃣ Verifying Fluent Bit sees logs (tail input)..."
kubectl logs -n kube-system -l name=fluent-bit --tail=30 | grep -E "(tail|log|flush|es)"

echo -e "\n🧪 If no errors above, generate logs (e.g. via vote) and check Elasticsearch:"
echo "   kubectl exec deploy/vote -- curl localhost"
echo "   kubectl run es-query --rm -it -n logging --image=curlimages/curl --restart=Never -- \\"
echo "     curl -s http://elasticsearch.logging.svc:9200/_cat/indices?v"
