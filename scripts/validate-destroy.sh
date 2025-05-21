#!/bin/bash
set -euo pipefail
#set -x  # Uncomment for step-by-step trace

CLUSTER_NAME="my-vote-cluster"
AWS_REGION="us-east-1"
TAG_KEY="Project"
TAG_VALUE="my-vote"

SCRIPT_NAME=$(basename "$0")
PASS_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
BLUE='\033[1;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header()  { echo -e "\n${BLUE}=== [$SCRIPT_NAME] $1 ===${NC}"; }
print_success() { echo -e "${GREEN}[✔] $1${NC}"; ((PASS_COUNT++)); }
print_fail()    { echo -e "${RED}[✘] $1${NC}"; ((FAIL_COUNT++)); }

# 0. Verify AWS credentials
print_header "0. Verifying AWS credentials"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  print_fail "AWS credentials invalid or expired"
  exit 1
else
  print_success "AWS credentials valid"
fi

# 0.1 Extract AWS Account ID safely
print_header "0.1 Extracting AWS Account ID"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [[ -z "$ACCOUNT_ID" ]]; then
  print_fail "Failed to retrieve AWS Account ID (empty or command failed)"
  exit 1
else
  print_success "AWS Account ID is $ACCOUNT_ID"
  echo "[DEBUG] ACCOUNT_ID=$ACCOUNT_ID"
fi

# 1. EKS cluster check
print_header "1. EKS Cluster Deletion Check"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" 2>/dev/null; then
  print_fail "EKS cluster \"$CLUSTER_NAME\" still exists"
else
  print_success "EKS cluster \"$CLUSTER_NAME\" is gone"
fi

# 2. VPC check
print_header "2. VPC Check (tagged $TAG_KEY=$TAG_VALUE)"
VPCS=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Vpcs[*].VpcId" --output text)

if [[ -z "$VPCS" ]]; then
  print_success "No tagged VPCs found"
else
  print_fail "Remaining VPC(s): $VPCS"
fi

# 3. EBS volume check
print_header "3. EBS Volume Check"
VOLUMES=$(aws ec2 describe-volumes \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Volumes[*].VolumeId" --output text)

if [[ -z "$VOLUMES" ]]; then
  print_success "No orphaned volumes found"
else
  print_fail "Found leftover volumes: $VOLUMES"
fi

# 4. Elastic IP check
print_header "4. Elastic IP Check"
EIPS=$(aws ec2 describe-addresses \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Addresses[*].PublicIp" --output text 2>/dev/null || echo "")

if [[ -z "$EIPS" ]]; then
  print_success "No orphaned Elastic IPs"
else
  print_fail "Found orphaned EIPs: $EIPS"
fi

# 5. IAM Role check
print_header "5. IAM Role Cleanup Check"
ROLES=$(aws iam list-roles \
  --query "Roles[?contains(RoleName, \`eksctl-$CLUSTER_NAME\`)].RoleName" \
  --output text)

if [[ -z "$ROLES" ]]; then
  print_success "No eksctl IAM roles remain"
else
  print_fail "Remaining IAM roles: $ROLES"
fi

# 6. OIDC Provider check
print_header "6. OIDC Provider Check"
OIDC_PROVIDERS=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[*].Arn" --output text)

OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" --output text 2>/dev/null || true)

if [[ "$OIDC_URL" == https://* ]]; then
  OIDC_HOST=$(echo "$OIDC_URL" | cut -d/ -f3)
  EXPECTED_OIDC="arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_HOST"
  if echo "$OIDC_PROVIDERS" | grep -q "$EXPECTED_OIDC"; then
    print_fail "OIDC provider still present: $EXPECTED_OIDC"
  else
    print_success "OIDC provider is gone"
  fi
else
  print_success "No OIDC URL found (control plane likely deleted)"
fi

# 7. ECR Repository check
print_header "7. ECR Repository Check"
ECR_REPOS=$(aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[*].repositoryName" --output text)

UNDELETED_REPOS=()
for repo in my-vote-vote my-vote-result my-vote-worker; do
  if echo "$ECR_REPOS" | grep -q "$repo"; then
    UNDELETED_REPOS+=("$repo")
  fi
done

if [[ ${#UNDELETED_REPOS[@]} -eq 0 ]]; then
  print_success "All ECR repos are deleted"
else
  print_fail "Remaining ECR repos: ${UNDELETED_REPOS[*]}"
fi

# ✅ Final Summary
print_header "🔍 Validation Summary"
echo -e "${BLUE}Passed: $PASS_COUNT${NC} | ${RED}Failed: $FAIL_COUNT${NC}"
[[ "$FAIL_COUNT" -eq 0 ]] && exit 0 || exit 1
