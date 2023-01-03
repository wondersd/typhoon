# network requires privileged libvirt
resource "libvirt_network" "this" {
  for_each = toset(var.libvirt_network_enabled ? ["enabled"] : [])

  name = var.cluster_domain_suffix

  mode = (var.libvirt_network_mode == null
    ? "none"
    : var.libvirt_network_mode
  )

  domain = var.cluster_domain_suffix

  bridge = ""

  addresses = (length(var.libvirt_network_cidrs) == 0
    ? ["10.0.0.0/16"]
    : var.libvirt_network_cidrs
  )
}

