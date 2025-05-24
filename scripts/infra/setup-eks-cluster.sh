#!/bin/bash

# === setup-eks-cluster.sh ===
# Automates Phase 3: EKS Cluster Provisioning & App Deployment
# Works with eksctl, ECR, and kubectl using your current YAML structure

set -e

CLUSTER_YAML="clusters/dev/cluster.yaml"
CLUSTER_NAME="my-vote-cluster"
REGION="us-east-1"
SERVICES=(vote result worker)

# 1. Create EKS Cluster
function create_cluster() {
  echo "\n🔧 Creating EKS cluster from $CLUSTER_YAML..."
  ./scripts/infra/create-cluster.sh "$CLUSTER_YAML"
}

# 2. Update kubeconfig and verify
function verify_kubectl_access() {
  echo "\n🔍 Verifying kubectl access..."
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
  kubectl get nodes
}

# 3. Patch aws-auth ConfigMap
function patch_aws_auth() {
  echo "\n🔐 Patching aws-auth ConfigMap..."
  ./scripts/infra/patch-aws-auth.sh
}

# 4. Build & Push Docker Images (from external my-vote repo)
function push_images() {
  echo "\n📦 Building and pushing images to ECR..."

  # Adjust path to external 'my-vote' repo (assumed sibling directory)
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../my-vote" && pwd)"

  for SERVICE_NAME in "${SERVICES[@]}"; do
    BUILD_CONTEXT="$REPO_ROOT/$SERVICE_NAME"

    if [[ ! -d "$BUILD_CONTEXT" ]]; then
      echo "❌ Error: build context not found at $BUILD_CONTEXT"
      exit 1
    fi

    echo "🔨 Building Docker image for $SERVICE_NAME from: $BUILD_CONTEXT"
    ./scripts/build/build-and-push.sh "$SERVICE_NAME" "$BUILD_CONTEXT"
  done
}

# 5. Apply All Manifests
function apply_manifests() {
  echo "\n🧩 Applying all manifests..."
  ./scripts/deploy/apply-all-manifests.sh
}

# 6. Validate Deployment Health
function validate_cluster() {
  echo "\n✅ Validating cluster and rollout status..."
  ./scripts/validate/validate-cluster.sh
  for svc in "${SERVICES[@]}"; do
    ./scripts/validate/rollout-check.sh "$svc"
  done
}

# === EXECUTE FULL PIPELINE ===
create_cluster
verify_kubectl_access
patch_aws_auth
push_images
apply_manifests
validate_cluster

echo "\n🎉 All done! Your EKS cluster is provisioned, app is deployed, and rollout is validated."
