#!/bin/bash
set -euo pipefail

CLUSTER_NAME="my-vote-cluster"
AWS_REGION="us-east-1"
TAG_KEY="Project"
TAG_VALUE="my-vote"

SCRIPT_NAME=$(basename "$0")

GREEN='\033[0;32m'
BLUE='\033[1;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header() { echo -e "\n${BLUE}=== [$SCRIPT_NAME] $1 ===${NC}"; }
print_success() { echo -e "${GREEN}[✔] $1${NC}"; }
print_fail() { echo -e "${RED}[✘] $1${NC}"; }

# Step 1: Delete the cluster
print_header "1. Deleting EKS Cluster with eksctl"
if eksctl delete cluster --name "$CLUSTER_NAME" --region "$AWS_REGION"; then
  print_success "EKS cluster $CLUSTER_NAME deleted"
else
  print_fail "Failed to delete cluster"
fi

# Step 2: Check for orphaned volumes
print_header "2. Checking for leftover EBS volumes"
VOLUMES=$(aws ec2 describe-volumes \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Volumes[*].VolumeId" --output text)

if [[ -z "$VOLUMES" ]]; then
  print_success "No orphaned EBS volumes"
else
  echo "Found volumes: $VOLUMES"
  for vol in $VOLUMES; do
    aws ec2 delete-volume --volume-id "$vol" --region "$AWS_REGION"
    echo "Deleted volume $vol"
  done
fi

# Step 3: Clean up Elastic IPs tagged by eksctl
print_header "3. Checking for orphaned Elastic IPs"
EIPS=$(aws ec2 describe-addresses \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Addresses[*].AllocationId" --output text)

if [[ -z "$EIPS" ]]; then
  print_success "No orphaned EIPs"
else
  for eip in $EIPS; do
    aws ec2 release-address --allocation-id "$eip" --region "$AWS_REGION"
    echo "Released EIP: $eip"
  done
fi

# Step 4: (Optional) Clean up IAM Roles created by eksctl
print_header "4. (Optional) IAM Role Cleanup"
ROLES=$(aws iam list-roles \
  --query "Roles[?contains(RoleName, \`eksctl-$CLUSTER_NAME\`)].RoleName" \
  --output text)

if [[ -z "$ROLES" ]]; then
  print_success "No leftover eksctl IAM roles"
else
  for role in $ROLES; do
    # Detach policies first
    policies=$(aws iam list-attached-role-policies --role-name "$role" \
              --query 'AttachedPolicies[*].PolicyArn' --output text)
    for policy in $policies; do
      aws iam detach-role-policy --role-name "$role" --policy-arn "$policy"
    done
    aws iam delete-role --role-name "$role"
    echo "Deleted IAM role: $role"
  done
fi

print_header "🧹 Cleanup Complete"
