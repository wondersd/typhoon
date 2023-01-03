resource "tls_private_key" "ssh_authorized_key" {
  # https://github.com/poseidon/typhoon/issues/919
  # https://github.com/coreos/fedora-coreos-tracker/issues/663#issuecomment-723279750
  # https://github.com/coreos/fedora-coreos-tracker/issues/699
  # https://github.com/poseidon/typhoon/issues/915
  # RSA support removed in coreos
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

# convience for use with 'ssh -i .id_rsa localtest.me -p 2222'
# may be able to use ssh-agent instead here
resource "local_sensitive_file" "private_key" {
  filename = format("%v/.id_rsa", path.module)
  content  = tls_private_key.ssh_authorized_key.private_key_pem
}

# convience for use with `kubeconfig --kubeconfig .kubeconfig.yaml'
resource "local_sensitive_file" "kubeconfig_admin" {
  filename = format("%v/.kubeconfig.yaml", path.module)
  content  = yamlencode(local.kubeconfig_admin_mod)
}

locals {
  kubeconfig_admin = yamldecode(module.typhoon.kubeconfig-admin)

  # terraform merge() doesnt do deep merges
  # just want to override clusters[0].cluster.server
  # to use our alt dns
  kubeconfig_admin_mod = merge(
    local.kubeconfig_admin,
    {
      clusters = [
        merge(
          local.kubeconfig_admin.clusters[0],
          {
            cluster = merge(
              local.kubeconfig_admin.clusters[0].cluster,
              {
                server = "https://k8s.localtest.me:6443"
              }
            )
          }
        )
      ]
    }
  )
}

provider "kubernetes" {
  # using our alt domain here
  host = local.kubeconfig_admin_mod.clusters[0].cluster.server

  client_certificate     = base64decode(local.kubeconfig_admin_mod.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kubeconfig_admin_mod.users[0].user.client-key-data)
  cluster_ca_certificate = base64decode(local.kubeconfig_admin_mod.clusters[0].cluster.certificate-authority-data)
}

module "typhoon" {
  source = "../libvirt/fedora-coreos/kubernetes"

  ssh_authorized_key = tls_private_key.ssh_authorized_key.public_key_openssh
  ssh_private_key    = tls_private_key.ssh_authorized_key.private_key_pem
  workers            = []
  controllers = [
    {
      name        = "test-1",
      domain      = "test-1.local",
      ip          = "10.0.3.16"
      mac         = "52:54:00:12:34:57"
      domain_type = "hvf"
    },
    # cant get intra vm networking to work using qemu sockets
    # {
    #   name   = "test-2",
    #   domain = "test-2.local",
    #   ip     = "10.0.3.17"
    #   mac = "52:54:00:12:34:58"
    #   domain_type = "hvf"
    # },
    # {
    #   name   = "test-3",
    #   domain = "test-3.local",
    #   ip     = "10.0.3.18"
    #   mac    = "52:54:00:12:34:59"
    #   domain_type = "hvf"
    # }
  ]

  cluster_name = "test"

  # will use domain name of first controller
  # SLiRP qemu network has no way I can find to inject DNS entries
  # concievibly possible to add to upstream dns (host /etc/hosts or physical network router)
  # but this will defeat the portability/isolation aspects of using this
  # will settle for a not fully multi-host setup

  k8s_domain_name = "test-1.local"

  # SLiRP network does not appear to retain any DNS entries for hosts on its dns server
  # will use ips instead
  k8s_use_ips = true

  # alt domain names for certs
  # will be able to use k8s.localtest.me from the host
  # to access the portforwarded control plane
  k8s_alt_domain_names = [
    "k8s.localtest.me"
  ]

  etcd_use_ips = true

  # https://builds.coreos.fedoraproject.org/browser?stream=stable&arch=x86_64
  os_version = "37.20221211.3.0"

  libvirt_storage_pool_path = abspath(format("%v/storage", path.module))
}

# brew installed libvert/qemu on macos doesnt play nice with sockets
# socket is not automatically detected and it seems that it only exists
# when virsh is running
provider "libvirt" {
  uri = format(
    "qemu:///session?mode=direct&proxy=native&socket=%v",
    pathexpand("~/.cache/libvirt/virtqemud-sock")
  )
}

resource "kubernetes_config_map" "test" {
  metadata {
    name = "test"
  }
  data = {}
}

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.1"
    }
  }
}