locals {
  remote_kernel = "https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/x86_64/fedora-coreos-${var.os_version}-live-kernel-x86_64"
  remote_initrd = [
    "https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/x86_64/fedora-coreos-${var.os_version}-live-initramfs.x86_64.img",
    "https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/x86_64/fedora-coreos-${var.os_version}-live-rootfs.x86_64.img"
  ]

  remote_args = [
    "ip=dhcp",
    "rd.neednet=1",
    "coreos.inst.install_dev=${var.install_disk}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "coreos.inst.image_url=https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/x86_64/fedora-coreos-${var.os_version}-metal.x86_64.raw.xz",
    "console=tty0",
    "console=ttyS0",
  ]

  cached_kernel = "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-kernel-x86_64"
  cached_initrd = [
    "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-initramfs.x86_64.img",
    "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-rootfs.x86_64.img"
  ]

  cached_args = [
    "ip=dhcp",
    "rd.neednet=1",
    "coreos.inst.install_dev=${var.install_disk}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
    "coreos.inst.image_url=${var.matchbox_http_endpoint}/assets/fedora-coreos/fedora-coreos-${var.os_version}-metal.x86_64.raw.xz",
    "console=tty0",
    "console=ttyS0",
  ]

  live_args = [
    "rd.neednet=1",
    "initrd=fedora-coreos-${var.os_version}-live-initramfs.x86_64.img",
    "console=tty0",
    "console=ttyS0",
    "ignition.firstboot",
    "ignition.platform.id=metal",
    "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}"
  ]

  kernel = var.cached_install ? local.cached_kernel : local.remote_kernel
  initrd = var.cached_install ? local.cached_initrd : local.remote_initrd
  args   = var.live ? local.live_args : (var.cached_install ? local.cached_args : local.remote_args)
}


// Fedora CoreOS controller profile
resource "matchbox_profile" "controllers" {
  count = length(var.controllers)
  name  = format("%s-controller-%s", var.cluster_name, var.controllers.*.name[count.index])

  kernel = (
    var.cached_install
    ? format(
      "/assets/fedora-coreos/fedora-coreos-%v-live-kernel-%v",
      lookup(var.controllers_version_override, element(var.controllers, count.index).name, var.os_version),
      lookup(var.controllers_arch_override, element(var.controllers, count.index).name, "x86_64")
    )
    : local.remote_kernel
  )
  initrd = (
    var.cached_install
    ? [
        format(
          "/assets/fedora-coreos/fedora-coreos-%v-live-initramfs.%v.img",
          lookup(var.controllers_version_override, element(var.controllers, count.index).name, var.os_version),
          lookup(var.controllers_arch_override, element(var.controllers, count.index).name, "x86_64")
        ),
        format(
          "/assets/fedora-coreos/fedora-coreos-%v-live-rootfs.%v.img",
          lookup(var.controllers_version_override, element(var.controllers, count.index).name, var.os_version),
          lookup(var.controllers_arch_override, element(var.controllers, count.index).name, "x86_64")
        )
      ]
    : local.remote_initrd
  )
  args = concat(
    (
      var.live
      ? [
          "rd.neednet=1",
          format(
            "initrd=fedora-coreos-%v-live-initramfs.%v.img",
            lookup(var.controllers_version_override, element(var.controllers, count.index).name, var.os_version),
            lookup(var.controllers_arch_override, element(var.controllers, count.index).name, "x86_64")
          ),
          "console=tty0",
          "console=ttyS0",
          "ignition.firstboot",
          "ignition.platform.id=metal",
          "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}"
        ]
      : (
        var.cached_install 
        ? [
            "ip=dhcp",
            "rd.neednet=1",
            "coreos.inst.install_dev=${var.install_disk}",
            "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
            format(
              "coreos.inst.image_url=${var.matchbox_http_endpoint}/assets/fedora-coreos/fedora-coreos-%v-metal.%v.raw.xz",
              lookup(var.controllers_version_override, element(var.controllers, count.index).name, var.os_version),
              lookup(var.controllers_arch_override, element(var.controllers, count.index).name, "x86_64")
            ),
            "console=tty0",
            "console=ttyS0",
          ]
        : local.remote_args
      )
    ),
    var.kernel_args
  )

  raw_ignition = data.ct_config.controller-ignitions.*.rendered[count.index]
}

data "ct_config" "controller-ignitions" {
  count = length(var.controllers)

  content  = data.template_file.controller-configs.*.rendered[count.index]
  strict   = true
  snippets = lookup(var.snippets, var.controllers.*.name[count.index], [])
}

data "template_file" "controller-configs" {
  count = length(var.controllers)

  template = file("${path.module}/fcc/controller.yaml")
  vars = {
    domain_name            = var.controllers.*.domain[count.index]
    etcd_name              = var.controllers.*.name[count.index]
    etcd_initial_cluster   = join(",", formatlist("%s=https://%s:2380", var.controllers.*.name, var.controllers.*.domain))
    cluster_dns_service_ip = module.bootstrap.cluster_dns_service_ip
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
    arch                   = lookup(var.controllers_arch_override, var.controllers.*.name[count.index], "x86_64")
  }
}

// Fedora CoreOS worker profile
resource "matchbox_profile" "workers" {
  count = length(var.workers)
  name  = format("%s-worker-%s", var.cluster_name, var.workers.*.name[count.index])

  kernel = (
    var.cached_install
    ? format(
      "/assets/fedora-coreos/fedora-coreos-%v-live-kernel-%v",
      lookup(var.workers_version_override, element(var.controllers, count.index).name, var.os_version),
      lookup(var.workers_arch_override, element(var.controllers, count.index).name, "x86_64")
    )
    : local.remote_kernel
  )
  initrd = (
    var.cached_install
    ? [
        format(
          "/assets/fedora-coreos/fedora-coreos-%v-live-initramfs.%v.img",
          lookup(var.workers_version_override, element(var.controllers, count.index).name, var.os_version),
          lookup(var.workers_arch_override, element(var.controllers, count.index).name, "x86_64")
        ),
        format(
          "/assets/fedora-coreos/fedora-coreos-%v-live-rootfs.%v.img",
          lookup(var.workers_version_override, element(var.controllers, count.index).name, var.os_version),
          lookup(var.workers_arch_override, element(var.controllers, count.index).name, "x86_64")
        )
      ]
    : local.remote_initrd
  )
  args = concat(
    (
      var.live
      ? [
          "rd.neednet=1",
          format(
            "initrd=fedora-coreos-%v-live-initramfs.%v.img",
            lookup(var.workers_version_override, element(var.controllers, count.index).name, var.os_version),
            lookup(var.workers_arch_override, element(var.controllers, count.index).name, "x86_64")
          ),
          "console=tty0",
          "console=ttyS0",
          "ignition.firstboot",
          "ignition.platform.id=metal",
          "ignition.config.url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}"
        ]
      : (
        var.cached_install 
        ? [
            "ip=dhcp",
            "rd.neednet=1",
            "coreos.inst.install_dev=${var.install_disk}",
            "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
            format(
              "coreos.inst.image_url=${var.matchbox_http_endpoint}/assets/fedora-coreos/fedora-coreos-%v-metal.%v.raw.xz",
              lookup(var.workers_version_override, element(var.controllers, count.index).name, var.os_version),
              lookup(var.workers_arch_override, element(var.controllers, count.index).name, "x86_64")
            ),
            "console=tty0",
            "console=ttyS0",
          ]
        : local.remote_args
      )
    ),
    var.kernel_args
  )

  raw_ignition = data.ct_config.worker-ignitions.*.rendered[count.index]
}

data "ct_config" "worker-ignitions" {
  count = length(var.workers)

  content  = data.template_file.worker-configs.*.rendered[count.index]
  strict   = true
  snippets = lookup(var.snippets, var.workers.*.name[count.index], [])
}

data "template_file" "worker-configs" {
  count = length(var.workers)

  template = file("${path.module}/fcc/worker.yaml")
  vars = {
    domain_name            = var.workers.*.domain[count.index]
    cluster_dns_service_ip = module.bootstrap.cluster_dns_service_ip
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
    node_labels            = join(",", lookup(var.worker_node_labels, var.workers.*.name[count.index], []))
    node_taints            = join(",", lookup(var.worker_node_taints, var.workers.*.name[count.index], []))
  }
}

