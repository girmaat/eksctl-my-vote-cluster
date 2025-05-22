#!/bin/bash

# NOTE: This script is duplicated in:
# 1. eksctl-my-vote-cluster/scripts/validate-cluster.sh
# 2. my-vote/scripts/infra/validate-cluster.sh
# Keep both copies in sync manually.
# Future improvements to fix this duplication use Git Submodule:
# In my-vote repo root run :
# git submodule add https://github.com/your-org/eksctl-my-vote-cluster scripts/infra

# Then you can reference:
# scripts/infra/scripts/validate-cluster.sh
# Jenkins can now access the script as part of app repo checkout.

set -euo pipefail

CLUSTER_NAME="my-vote-cluster"
AWS_REGION="us-east-1"
NAMESPACE="monitoring"
SERVICE_ACCOUNT="fluentbit"
SCRIPT_NAME=$(basename "$0")

PASS_COUNT=0
FAIL_COUNT=0

# Colors for formatting output
GREEN='\033[0;32m'
BLUE='\033[1;34m'
RED='\033[0;31m'
NC='\033[0m'

# Utility functions
print_header() { echo -e "\n${BLUE}=== [$SCRIPT_NAME] $1 ===${NC}"; }
print_success() { echo -e "${GREEN}[✔] $1${NC}"; ((PASS_COUNT++)); }
print_fail() { echo -e "${RED}[✘] $1${NC}"; ((FAIL_COUNT++)); }

# 1. Check if the EKS cluster exists
print_header "1. EKS Cluster Check"
if eksctl get cluster --region "$AWS_REGION" | grep -q "$CLUSTER_NAME"; then
  print_success "Cluster $CLUSTER_NAME exists in region $AWS_REGION"
else
  print_fail "Cluster $CLUSTER_NAME not found"
fi

# 2. Ensure all nodes are Ready
print_header "2. Node Health Check"
if kubectl get nodes > /dev/null 2>&1; then
  READY=$(kubectl get nodes --no-headers | grep -c ' Ready')
  TOTAL=$(kubectl get nodes --no-headers | wc -l)
  [[ "$READY" -eq "$TOTAL" ]] && print_success "All $READY node(s) are Ready" || print_fail "$READY of $TOTAL node(s) are Ready"
else
  print_fail "kubectl get nodes failed"
fi

# 3. Check if aws-auth ConfigMap is present
print_header "3. aws-auth ConfigMap Check"
if kubectl get configmap aws-auth -n kube-system > /dev/null 2>&1; then
  print_success "aws-auth ConfigMap exists"
else
  print_fail "aws-auth ConfigMap missing"
fi

# 4. Confirm that OIDC issuer is configured
print_header "4. OIDC Issuer Check"
OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" --output text 2>/dev/null)
if [[ "$OIDC_URL" == https://* ]]; then
  print_success "OIDC issuer URL is set: $OIDC_URL"
else
  print_fail "OIDC issuer URL missing"
fi

# 5. Run a pod to test internet connectivity (egress)
print_header "5. Test Pod Egress to Internet"
if kubectl run testcurl --image=radial/busyboxplus:curl -i --tty --rm --restart=Never -- curl -s https://www.google.com | grep -q "<html"; then
  print_success "Pods have internet access"
else
  print_fail "Pod cannot access internet (egress failure)"
fi

# 6. Check if FluentBit service account is IRSA-annotated
print_header "6. IRSA Annotation Check (Optional)"
if kubectl get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null | grep -q 'arn:'; then
  print_success "IRSA annotation present on $SERVICE_ACCOUNT in $NAMESPACE"
else
  print_fail "IRSA annotation missing or not set yet"
fi

# Final result summary
print_header "🧪 Validation Summary"
echo -e "${BLUE}Passed: $PASS_COUNT${NC} | ${RED}Failed: $FAIL_COUNT${NC}"
[[ "$FAIL_COUNT" -eq 0 ]] && exit 0 || exit 1
