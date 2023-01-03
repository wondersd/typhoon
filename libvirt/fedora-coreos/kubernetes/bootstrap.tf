# Kubernetes assets (kubeconfig, manifests)
module "bootstrap" {
  source = "git::https://github.com/wondersd/terraform-render-bootstrap.git?ref=94af132e6fa0fd7ee4f2b3e91b1a68a928e9ee55"

  cluster_name = var.cluster_name
  api_servers  = concat([var.k8s_domain_name], var.k8s_alt_domain_names)
  api_server_ips = concat(
    [
      for controller in var.controllers :
      controller.ip if contains(keys(controller), "ip")
    ],
    var.k8s_alt_ips
  )
  api_server_use_ips = var.k8s_use_ips
  etcd_servers       = var.controllers.*.domain
  etcd_server_ips = [
    for controller in var.controllers :
    controller.ip if contains(keys(controller), "ip")
  ]
  etcd_use_ips                    = var.etcd_use_ips
  networking                      = var.networking
  network_mtu                     = var.network_mtu
  network_ip_autodetection_method = var.network_ip_autodetection_method
  pod_cidr                        = var.pod_cidr
  service_cidr                    = var.service_cidr
  cluster_domain_suffix           = var.cluster_domain_suffix
  enable_reporting                = var.enable_reporting
  enable_aggregation              = var.enable_aggregation
}


