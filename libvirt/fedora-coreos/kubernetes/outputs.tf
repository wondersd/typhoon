output "kubeconfig-admin" {
  value     = module.bootstrap.kubeconfig-admin
  sensitive = true
  depends_on = [
    # kubeconfig-admin cannot meaningfully be used until
    # after bootstrap has completed
    null_resource.bootstrap
  ]
}

# Outputs for debug

output "assets_dist" {
  value     = module.bootstrap.assets_dist
  sensitive = true
}