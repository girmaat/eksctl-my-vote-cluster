module "ecr_vote" {
  source = "../../modules/ecr"
  name   = "my-vote-vote"
  tags = {
    Cluster     = "my-vote-cluster"
    Project     = "my-vote"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

module "ecr_result" {
  source = "../../modules/ecr"
  name   = "my-vote-result"
  tags = {
    Cluster     = "my-vote-cluster"
    Project     = "my-vote"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

module "ecr_worker" {
  source = "../../modules/ecr"
  name   = "my-vote-worker"
  tags = {
    Cluster     = "my-vote-cluster"
    Project     = "my-vote"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
