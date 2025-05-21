#!/bin/bash
set -euo pipefail

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

print_header() { echo -e "\n${BLUE}=== [$SCRIPT_NAME] $1 ===${NC}"; }
print_success() { echo -e "${GREEN}[✔] $1${NC}"; ((PASS_COUNT++)); }
print_fail() { echo -e "${RED}[✘] $1${NC}"; ((FAIL_COUNT++)); }

# 1. EKS cluster check
print_header "1. EKS Cluster Deletion Check"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" 2>/dev/null; then
  print_fail "EKS cluster $CLUSTER_NAME still exists"
else
  print_success "EKS cluster $CLUSTER_NAME is gone"
fi

# 2. VPC check (by tag)
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

# 4. EIP check
print_header "4. Elastic IP Check"
EIPS=$(aws ec2 describe-addresses \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Addresses[*].PublicIp" --output text)
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
  print_fail "Remaining eksctl IAM roles: $ROLES"
fi

# Summary
print_header "🔍 Validation Summary"
echo -e "${BLUE}Passed: $PASS_COUNT${NC} | ${RED}Failed: $FAIL_COUNT${NC}"
[[ "$FAIL_COUNT" -eq 0 ]] && exit 0 || exit 1
