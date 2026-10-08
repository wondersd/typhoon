# Kubernetes assets (kubeconfig, manifests)
module "bootstrap" {
  source                         = "git::https://github.com/wondersd/terraform-render-bootstrap.git?ref=13d1694312ad2f1a32cd8b48c09b03ce8855d46f"
  cluster_name                   = var.cluster_name
  api_servers                    = concat([var.k8s_domain_name], var.k8s_alt_domain_names)
  service_account_issuer         = var.service_account_issuer
  etcd_servers                   = var.controllers.*.domain
  networking                     = var.networking
  pod_cidr                       = var.pod_cidr
  service_cidr                   = var.service_cidr
  components                     = var.components
  apiserver_annotations          = var.apiserver_annotations
  apiserver_additional_args      = var.apiserver_additional_args
  apiserver_resources            = var.apiserver_resources
  apiserver_securitycontext      = var.apiserver_securitycontext
  controller_manager_annotations = var.controller_manager_annotations
  controller_manager_resources   = var.controller_manager_resources
  scheduler_annotations          = var.scheduler_annotations
  scheduler_resources            = var.scheduler_resources
}


