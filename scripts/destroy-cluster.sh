#!/bin/bash
set -euo pipefail

CLUSTER_NAME="my-vote-cluster"
AWS_REGION="us-east-1"
TAG_KEY="Project"
TAG_VALUE="my-vote"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

SCRIPT_NAME=$(basename "$0")
GREEN='\033[0;32m'
BLUE='\033[1;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header()  { echo -e "\n${BLUE}=== [$SCRIPT_NAME] $1 ===${NC}"; }
print_success() { echo -e "${GREEN}[✔] $1${NC}"; }
print_fail()    { echo -e "${RED}[✘] $1${NC}"; }

confirm() {
  echo -e "${RED}⚠️  Are you sure you want to destroy the EKS cluster \"$CLUSTER_NAME\" and all associated resources? (yes/no)${NC}"
  read -r ans
  [[ "$ans" == "yes" ]] || { echo -e "${RED}Aborted.${NC}"; exit 1; }
}

confirm

# 1. Delete PDBs (to avoid eviction blocks)
print_header "1. Deleting PodDisruptionBudgets in kube-system"
PDBS=$(kubectl get pdb -n kube-system -o name 2>/dev/null || true)
if [[ -z "$PDBS" ]]; then
  print_success "No PDBs found in kube-system"
else
  for pdb in $PDBS; do
    kubectl delete "$pdb" -n kube-system || true
    echo "Deleted $pdb"
  done
  print_success "All kube-system PDBs deleted"
fi

# 2. Force drain all nodes
print_header "2. Draining all nodes (forcefully)"
NODES=$(kubectl get nodes -o name 2>/dev/null || true)
if [[ -z "$NODES" ]]; then
  echo "No nodes found or kubeconfig invalid. Skipping drain."
else
  for node in $NODES; do
    echo -e "${BLUE}🔄 Draining $node${NC}"
    kubectl drain "$node" --ignore-daemonsets --force --delete-emptydir-data --grace-period=0 || true
  done
  print_success "Node draining complete"
fi

# 3. Delete EKS cluster
print_header "3. Deleting EKS Cluster with eksctl"
if eksctl delete cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" ; then
  print_success "EKS cluster $CLUSTER_NAME deleted"
else
  print_fail "Cluster deletion failed"
  exit 1
fi

# 4. Delete ECR repos
print_header "4. Deleting ECR Repositories"
for repo in my-vote-vote my-vote-result my-vote-worker; do
  if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" > /dev/null 2>&1; then
    aws ecr delete-repository --repository-name "$repo" --region "$AWS_REGION" --force
    print_success "Deleted ECR repo: $repo"
  else
    echo "ECR repo $repo not found"
  fi
done

# 5. Delete orphaned EBS volumes
print_header "5. Checking for orphaned EBS volumes"
VOLUMES=$(aws ec2 describe-volumes \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Volumes[*].VolumeId" --output text)

if [[ -z "$VOLUMES" ]]; then
  print_success "No orphaned EBS volumes"
else
  for vol in $VOLUMES; do
    aws ec2 delete-volume --volume-id "$vol" --region "$AWS_REGION"
    echo "Deleted volume $vol"
  done
fi

# 6. Release orphaned Elastic IPs
print_header "6. Releasing orphaned Elastic IPs"
EIPS=$(aws ec2 describe-addresses \
  --region "$AWS_REGION" \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Addresses[*].AllocationId" --output text)

if [[ -z "$EIPS" ]]; then
  print_success "No orphaned Elastic IPs"
else
  for eip in $EIPS; do
    aws ec2 release-address --allocation-id "$eip" --region "$AWS_REGION"
    echo "Released EIP: $eip"
  done
fi

# 7. Delete IAM roles
print_header "7. IAM Role Cleanup"
ROLES=$(aws iam list-roles \
  --query "Roles[?contains(RoleName, \`eksctl-$CLUSTER_NAME\`)].RoleName" \
  --output text)

if [[ -z "$ROLES" ]]; then
  print_success "No leftover eksctl IAM roles"
else
  for role in $ROLES; do
    policies=$(aws iam list-attached-role-policies --role-name "$role" \
              --query 'AttachedPolicies[*].PolicyArn' --output text)
    for policy in $policies; do
      aws iam detach-role-policy --role-name "$role" --policy-arn "$policy"
    done
    aws iam delete-role --role-name "$role"
    echo "Deleted IAM role: $role"
  done
fi

# 8. Delete OIDC provider
print_header "8. Deleting OIDC Provider (if exists)"
OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" --output text 2>/dev/null || true)

if [[ "$OIDC_URL" == https://* ]]; then
  OIDC_HOST=$(echo "$OIDC_URL" | cut -d/ -f3)
  PROVIDER_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_HOST"
  if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" > /dev/null 2>&1; then
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN"
    print_success "Deleted OIDC provider: $PROVIDER_ARN"
  else
    echo "OIDC provider $PROVIDER_ARN not found"
  fi
else
  echo "OIDC URL not found or control plane already deleted"
fi

print_header "🧹 Cluster Teardown Complete"
