output "ecr_vote_url" {
  value = module.ecr_vote.repository_url
}

output "ecr_result_url" {
  value = module.ecr_result.repository_url
}

output "ecr_worker_url" {
  value = module.ecr_worker.repository_url
}
