========================
1. Project Title
========================
    eksctl-my-vote-cluster: Infrastructure for my-vote EKS

========================
2. Project Description
========================
This repository manages the infrastructure for the my-vote app:

    EKS cluster via eksctl

    ECR repositories via Terraform

    IAM roles for nodes and IRSA

========================
3. Table of Contents
========================
    Project Description

    Installation Instructions

    Usage Instructions

    Configuration

    Validation and Destruction

    License

========================
4. Installation Instructions
========================
    Install AWS CLI, eksctl, terraform, and kubectl

    Clone the repo and run:

    eksctl create cluster -f clusters/dev/cluster.yaml
    terraform -chdir=envs/dev apply

========================
5. Usage Instructions
========================
    Validate cluster state: scripts/validate-cluster.sh

    Destroy cluster and ECR: scripts/destroy-cluster.sh

    Check nodegroups and OIDC: audit-eks-resources.sh

========================
6. Configuration
========================

    EKS config: clusters/dev/eksctl-cluster.yaml

    Terraform modules: modules/ecr/

    Cluster setup: envs/dev/*.tf

    Validation scripts: scripts/*.sh
