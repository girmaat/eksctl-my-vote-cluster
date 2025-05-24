#!/bin/bash
set -euo pipefail

CLUSTER_NAME="my-vote-cluster"
AWS_REGION="us-east-1"
SCRIPT_NAME=$(basename "$0")

BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${BLUE}🔷 [$SCRIPT_NAME] $*${NC}"; }
ok()     { echo -e "${GREEN}✅ $*${NC}"; }
error()  { echo -e "${RED}❌ $*${NC}"; }

# Step 1: Get private DNS name of first node
log "Getting first node's internal DNS name..."
NODE_DNS=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$NODE_DNS" ]]; then
  error "No nodes found in the cluster"
  exit 1
fi

log "Node DNS: $NODE_DNS"

# Step 2: Lookup EC2 instance by private DNS
log "Finding EC2 instance for $NODE_DNS..."
INSTANCE_PROFILE_ARN=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=private-dns-name,Values=$NODE_DNS" \
  --query "Reservations[].Instances[].IamInstanceProfile.Arn" \
  --output text)

if [[ -z "$INSTANCE_PROFILE_ARN" ]]; then
  error "Failed to find instance profile for $NODE_DNS"
  exit 1
fi

INSTANCE_PROFILE_NAME=$(basename "$INSTANCE_PROFILE_ARN")
log "Instance profile: $INSTANCE_PROFILE_NAME"

# Step 3: Extract role ARN from instance profile
ROLE_ARN=$(aws iam get-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --query "InstanceProfile.Roles[0].Arn" \
  --output text)

if [[ -z "$ROLE_ARN" ]]; then
  error "Failed to extract IAM role ARN from profile"
  exit 1
fi

log "IAM Role ARN: $ROLE_ARN"

# Step 4: Generate and apply aws-auth ConfigMap
log "Patching aws-auth ConfigMap..."

TMP_FILE=$(mktemp)
cat <<EOF > "$TMP_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $ROLE_ARN
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

kubectl apply -f "$TMP_FILE"
rm -f "$TMP_FILE"
ok "aws-auth ConfigMap patched successfully!"
