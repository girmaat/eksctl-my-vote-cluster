#!/bin/bash

# Usage: ./build-and-push.sh <service_name>
# Example: ./build-and-push.sh vote

set -e

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: $0 <service_name>"
  exit 1
fi

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/my-vote-$SERVICE_NAME"

# Authenticate Docker to AWS ECR
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Build the Docker image
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker build -t "$ECR_REPO:latest" "$PROJECT_ROOT/manifests/$SERVICE_NAME"

# Push the image to ECR
docker push "$ECR_REPO:latest"
