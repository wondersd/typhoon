# Fedora CoreOS workers
data "ct_config" "workers" {
  count = length(var.workers)
  content = templatefile("${path.module}/butane/worker.yaml", {
    domain_name            = var.workers.*.domain[count.index]
    cluster_dns_service_ip = module.bootstrap.cluster_dns_service_ip
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
    node_labels            = join(",", lookup(var.worker_node_labels, var.workers.*.name[count.index], []))
    node_taints            = join(",", lookup(var.worker_node_taints, var.workers.*.name[count.index], []))
  })
  strict   = true
  snippets = lookup(var.snippets, var.workers.*.name[count.index], [])
}
