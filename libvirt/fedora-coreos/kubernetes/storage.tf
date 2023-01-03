resource "libvirt_pool" "this" {
  name = var.cluster_domain_suffix
  type = "dir"
  path = var.libvirt_storage_pool_path
}