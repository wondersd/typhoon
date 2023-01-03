variable "cluster_name" {
  type        = string
  description = "Unique cluster name"
}

variable "os_stream" {
  type        = string
  description = "Fedora CoreOS release stream (e.g. stable, testing, next)"
  default     = "stable"

  validation {
    condition     = contains(["stable", "testing", "next"], var.os_stream)
    error_message = "The os_stream must be stable, testing, or next."
  }
}

variable "os_version" {
  type        = string
  description = "Fedora CoreOS version to PXE and install (e.g. 31.20200310.3.0)"
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key to use when connecting as 'core' to bootstrap, defaults to current users private key."
  default     = null
  sensitive   = true
}

# machines

variable "controllers" {
  type = any

  validation {
    condition     = can(length(var.controllers))
    error_message = "var.controllers must be a list"
  }

  validation {
    condition = length(
      [
        for controller in var.controllers :
        controller.name if contains(keys(controller), "name")
      ]
    ) == length(var.controllers)
    error_message = "var.controllers must contain { name = 'node' } for each entry"
  }

  validation {
    condition = length(
      [
        for controller in var.controllers :
        controller.domain if contains(keys(controller), "domain")
      ]
    ) == length(var.controllers)
    error_message = "var.controllers must contain { domain = 'node' } for each entry"
  }

  description = <<EOD
List of controller machine details (unique name, identifying MAC address, FQDN)

`ip`                  - required if qemu SLiRP network is used
`libvirt_domain_type` - defaults to qemu (full emulation), use 'kvm' for linux hosts or 'hvf' for modern macOS

Example:

[
  {
    name                = "node1"
    domain              = "node1.local"
    ip                  = "10.0.2.15"
    libvirt_domain_type = "hvf"
  },
  {
    name                = "node2"
    domain              = "node2.local"
    ip                  = "10.0.2.16"
    libvirt_domain_type = "qemu"
  }
]
EOD
}

variable "workers" {
  type = list(object({
    name   = string
    domain = string
  }))
  description = <<EOD
List of worker machine details (unique name, identifying MAC address, FQDN)
[
  { name = "node2", mac = "52:54:00:b2:2f:86", domain = "node2.example.com"},
  { name = "node3", mac = "52:54:00:c3:61:77", domain = "node3.example.com"}
]
EOD
}

variable "snippets" {
  type        = map(list(string))
  description = "Map from machine names to lists of Butane snippets"
  default     = {}
}

variable "worker_node_labels" {
  type        = map(list(string))
  description = "Map from worker names to lists of initial node labels"
  default     = {}
}

variable "worker_node_taints" {
  type        = map(list(string))
  description = "Map from worker names to lists of initial node taints"
  default     = {}
}

# configuration

variable "k8s_domain_name" {
  type        = string
  description = "Controller DNS name which resolves to a controller instance. Workers and kubeconfig's will communicate with this endpoint (e.g. cluster.example.com)"
}

variable "k8s_alt_domain_names" {
  type        = list(string)
  default     = []
  description = "Alternative Controller DNS names which resolve to a controller instance(s)"
}

variable "k8s_alt_ips" {
  type        = list(string)
  default     = []
  description = "Alternative Controller IPs which resolve to a controller instance(s)"
}

variable "k8s_use_ips" {
  type        = bool
  default     = false
  description = "Use ip addresses instead of domains to reach apiserver"
}

variable "etcd_use_ips" {
  type        = bool
  default     = false
  description = "Use ip addresses instead of domains to reach etcd"
}

variable "ssh_authorized_key" {
  type        = string
  description = "SSH public key for user 'core'"
}

variable "networking" {
  type        = string
  description = "Choice of networking provider (flannel, calico, or cilium)"
  default     = "cilium"
}

variable "network_mtu" {
  type        = number
  description = "CNI interface MTU (applies to calico only)"
  default     = 1480
}

variable "network_ip_autodetection_method" {
  type        = string
  description = "Method to autodetect the host IPv4 address (applies to calico only)"
  default     = "first-found"
}

variable "pod_cidr" {
  type        = string
  description = "CIDR IPv4 range to assign Kubernetes pods"
  default     = "10.2.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = <<EOD
CIDR IPv4 range to assign Kubernetes services.
The 1st IP will be reserved for kube_apiserver, the 10th IP will be reserved for coredns.
EOD
  default     = "10.3.0.0/16"
}

# optional

variable "enable_reporting" {
  type        = bool
  description = "Enable usage or analytics reporting to upstreams (Calico)"
  default     = false
}

variable "enable_aggregation" {
  type        = bool
  description = "Enable the Kubernetes Aggregation Layer"
  default     = true
}

# unofficial, undocumented, unsupported

variable "cluster_domain_suffix" {
  description = "Queries for domains with the suffix will be answered by coredns. Default is cluster.local (e.g. foo.default.svc.cluster.local) "
  type        = string
  default     = "cluster.local"
}

# libvirt 

variable "libvirt_network_enabled" {
  type        = bool
  default     = false
  description = "create libvirt network, requires privileged libvirt"
}

variable "libvirt_network_mode" {
  type    = string
  default = null
}

variable "libvirt_network_cidrs" {
  type    = list(string)
  default = []
}

variable "libvirt_storage_pool_path" {
  type = string
}

variable "libvirt_qemu_slirp_network_enabled" {
  type        = bool
  default     = true
  description = "use qemus SLiRP user mode networking"
}

variable "libvirt_qemu_slirp_network_ssh_port_forward_start" {
  type        = number
  default     = 2222
  description = "port to start forwarding ssh to guest vms, controllers are allocated first then workers"
}

variable "libvirt_qemu_slirp_network_api_server_port_forward" {
  type        = number
  default     = 6443
  description = "port to start forwarding kube-apiserver of controller-0"
}

variable "libvirt_qemu_slirp_network_gateway" {
  type    = string
  default = "10.0.2.2"
}

variable "libvirt_qemu_slirp_network_nameserver" {
  type    = string
  default = "10.0.2.3"
}