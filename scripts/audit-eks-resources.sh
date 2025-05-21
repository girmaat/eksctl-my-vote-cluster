#!/bin/bash
set -euo pipefail

CLUSTER_NAME="my-vote-cluster"
AWS_REGION="us-east-1"
PROJECT_TAG_KEY="Project"
PROJECT_TAG_VALUE="my-vote"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

ask_to_continue() {
  echo -n "👉 Do you want to delete this manually now? (yes/no/skip all): "
  read -r choice
  case "$choice" in
    yes) return 0 ;;
    no)  return 1 ;;
    skip*) echo "⚠️  Skipping all further deletions."; exit 0 ;;
    *)    echo "Invalid input. Exiting."; exit 1 ;;
  esac
}

print_header() {
  echo -e "\n\033[1;34m=== Checking: $1 ===\033[0m"
}

# 1. EKS Cluster
print_header "EKS Cluster"
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "❌ Cluster $CLUSTER_NAME still exists."
else
  echo "✅ Cluster $CLUSTER_NAME is gone."
fi

# 2. VPCs tagged to project
print_header "VPCs tagged $PROJECT_TAG_KEY=$PROJECT_TAG_VALUE"
VPCS=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=tag:$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" \
  --query "Vpcs[*].VpcId" --output text)

if [[ -z "$VPCS" ]]; then
  echo "✅ No tagged VPCs found."
else
  echo "❌ Found VPCs: $VPCS"
  ask_to_continue
fi

# 3. EBS Volumes
print_header "EBS Volumes tagged $PROJECT_TAG_KEY=$PROJECT_TAG_VALUE"
VOLUMES=$(aws ec2 describe-volumes \
  --region "$AWS_REGION" \
  --filters "Name=tag:$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" \
  --query "Volumes[*].VolumeId" --output text)

if [[ -z "$VOLUMES" ]]; then
  echo "✅ No orphaned volumes found."
else
  echo "❌ Orphaned volumes: $VOLUMES"
  ask_to_continue
fi

# 4. Elastic IPs
print_header "Elastic IPs tagged $PROJECT_TAG_KEY=$PROJECT_TAG_VALUE"
EIPS=$(aws ec2 describe-addresses \
  --region "$AWS_REGION" \
  --filters "Name=tag:$PROJECT_TAG_KEY,Values=$PROJECT_TAG_VALUE" \
  --query "Addresses[*].AllocationId" --output text)

if [[ -z "$EIPS" ]]; then
  echo "✅ No orphaned Elastic IPs."
else
  echo "❌ Found orphaned EIPs: $EIPS"
  ask_to_continue
fi

# 5. IAM Roles
print_header "IAM Roles from eksctl for $CLUSTER_NAME"
ROLES=$(aws iam list-roles \
  --query "Roles[?contains(RoleName, \`eksctl-$CLUSTER_NAME\`)].RoleName" \
  --output text)

if [[ -z "$ROLES" ]]; then
  echo "✅ No eksctl IAM roles remain."
else
  echo "❌ Found roles: $ROLES"
  ask_to_continue
fi

# 6. OIDC Provider
print_header "OIDC Provider for $CLUSTER_NAME"
OIDC_HOST=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" --output text 2>/dev/null | cut -d/ -f3 || true)

if [[ -n "$OIDC_HOST" ]]; then
  OIDC_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_HOST"
  echo "❌ OIDC provider still exists: $OIDC_ARN"
  ask_to_continue
else
  echo "✅ No OIDC provider found."
fi

# 7. ECR Repositories
print_header "ECR Repositories (vote, result, worker)"
for repo in my-vote-vote my-vote-result my-vote-worker; do
  if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "❌ ECR repository exists: $repo"
    ask_to_continue
  else
    echo "✅ ECR repo $repo is deleted."
  fi
done

# 8. eksctl CloudFormation Stacks
print_header "eksctl CloudFormation Stacks"
STACKS=$(aws cloudformation describe-stacks --region "$AWS_REGION" \
  --query "Stacks[?starts_with(StackName, 'eksctl-$CLUSTER_NAME')].StackName" --output text)

if [[ -z "$STACKS" ]]; then
  echo "✅ No eksctl-related stacks found."
else
  echo "❌ Found CloudFormation stacks: $STACKS"
  ask_to_continue
fi

echo -e "\n\033[0;32m🎉 Manual audit complete.\033[0m"
