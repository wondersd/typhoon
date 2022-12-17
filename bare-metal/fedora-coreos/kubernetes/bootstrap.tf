# Kubernetes assets (kubeconfig, manifests)
module "bootstrap" {
  source = "git::https://github.com/poseidon/terraform-render-bootstrap.git?ref=9af5837c35411939111dff1b00e52faf26b179a2"

  cluster_name           = var.cluster_name
  api_servers            = concat([var.k8s_domain_name], var.k8s_alt_domain_names)
  service_account_issuer = var.service_account_issuer
  etcd_servers           = var.controllers.*.domain
  networking             = var.networking
  pod_cidr               = var.pod_cidr
  service_cidr           = var.service_cidr
  components             = var.components
}


