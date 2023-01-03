# Fedora CoreOS controllers
data "ct_config" "controllers" {
  count = length(var.controllers)
  content = templatefile("${path.module}/butane/controller.yaml", {
    domain_name = var.controllers.*.domain[count.index]
    ip          = var.controllers.*.ip[count.index]
    prefix      = "/24"
    gateway     = var.libvirt_qemu_slirp_network_gateway
    nameserver  = var.libvirt_qemu_slirp_network_nameserver
    etcd_server = (var.etcd_use_ips
      ? var.controllers.*.ip[count.index]
      : var.controllers.*.domain[count.index]
    )
    etcd_name = var.controllers.*.name[count.index]
    etcd_initial_cluster = join(",",
      formatlist(
        "%s=https://%s:2380",
        var.controllers.*.name,
        (var.etcd_use_ips
          ? var.controllers.*.ip
          : var.controllers.*.domain
        )
      )
    )
    cluster_dns_service_ip = module.bootstrap.cluster_dns_service_ip
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
  })
  strict   = true
  snippets = lookup(var.snippets, var.controllers.*.name[count.index], [])
}

resource "libvirt_ignition" "controllers" {
  count = length(var.controllers)
  # uniquely identify based on contents of ignition so it can be
  # created before destroyed
  name = format("controller-ign-%v-%v",
    count.index,
    substr(sha512(data.ct_config.controllers[count.index].rendered), 0, 5)
  )
  content = data.ct_config.controllers[count.index].rendered
  pool    = libvirt_pool.this.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "libvirt_volume" "controllers" {
  count = length(var.controllers)
  # bind to ignitition content
  # create a new volume each time ignition is changed
  # so it will force a new volume and subsequent domain creation
  # since changes to ignition only matter for first boot
  name = format("controller-%v-%v",
    count.index,
    substr(sha512(libvirt_ignition.controllers[count.index].content), 0, 5)
  )
  pool           = libvirt_pool.this.name
  base_volume_id = libvirt_volume.coreos.id

  lifecycle {
    create_before_destroy = true
  }
}

# ran with export TERRAFORM_LIBVIRT_TEST_DOMAIN_TYPE=qemu
# for OSX since kvm cant be used
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/12ed41017b5cf2181f39ddc366ab66ed45770cf7/libvirt/domain_def.go#L88
# the above is no longer required with xslt transform below
resource "libvirt_domain" "controllers" {
  count           = length(var.controllers)
  name            = libvirt_volume.controllers[count.index].name
  vcpu            = lookup(var.controllers[count.index], "vcpu", 1)
  memory          = lookup(var.controllers[count.index], "memory", 2048)
  arch            = "x86_64"
  coreos_ignition = libvirt_ignition.controllers[count.index].id

  disk {
    volume_id = libvirt_volume.controllers[count.index].id
    scsi      = "true"
  }

  # allows for $ virsh console --domain controller-n-xxxxx
  # to see the serial console while booting
  console {
    type        = "pty"
    target_port = "0" # dunno what this value is for
  }

  # https://github.com/containers/podman/blob/main/pkg/machine/qemu/machine.go#L131
  # https://gist.github.com/dghubble/c2dc319249b156db06aff1d49c15272e#--tips-networking
  # https://qemu.readthedocs.io/en/latest/system/device-emulation.html#device-buses
  # https://wiki.qemu.org/Documentation/Networking
  # https://qemu.readthedocs.io/en/latest/system/invocation.html#sec-005finvocation

  #   <qemu:commandline>
  #     <qemu:arg value='-fw_cfg'/>
  #     <qemu:arg value='....'/>
  #     <qemu:arg value='-netdev'/>
  #     <qemu:arg value='user,id=net0,hostfwd=tcp::2222-:22'/>
  #     <qemu:arg value='-device'/>
  #     <qemu:arg value='e1000,bus=pci.0,addr=7,netdev=net0'/>
  #   </qemu:commandline>
  # </domain>
  # virsh dumpxml --domain controller-n-xxxxx

  # pci.0 addr 2-6 consumed by other devices, 7 seems to be first open slot
  # qemu-system-x86_64: -device {"driver":"virtio-scsi-pci","id":"scsi0","bus":"pci.0","addr":"0x3"}: PCI: slot 3 function 0 not available for virtio-scsi-pci, in use by virtio-net-pci,id=(null)

  # xslt transform to inject modifications not directly supported by the libvirt terraform provider
  # here for
  # * switching domain type to qemu from the hardcoded 'kvm' (developing on macOS)
  # * setup and configure SLiRP usermode networking
  # libvirt seems to be pretty picky about namespaces for elements
  xml {
    xslt = <<EOF
<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0">
  <xsl:output method="xml" omit-xml-declaration="yes" indent="yes"/>
  <xsl:strip-space elements="*" /> 
  <xsl:template match="node()|@*">
   <xsl:copy>
     <xsl:apply-templates select="node()|@*"/>
   </xsl:copy>
  </xsl:template>
  <xsl:template match="/domain/@type">
  <xsl:attribute name="type">
    <xsl:value-of select="'${lookup(var.controllers[count.index], "domain_type", "qemu")}'"/>
  </xsl:attribute>
  </xsl:template>
  <xsl:template match="/domain/qemu:commandline">
   <xsl:element name="{name()}" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
    <xsl:apply-templates/>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'-netdev'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'user,${join(",",
    [
      "id=net0",
      "hostfwd=tcp::${var.libvirt_qemu_slirp_network_ssh_port_forward_start + count.index}-10.0.2.15:22",
      "hostname=${var.controllers[count.index].name}",
      "domainname=${var.controllers[count.index].domain}"
    ],
    # only port forward the first controller to host
    (count.index == 0
      ? [
        "hostfwd=tcp::${var.libvirt_qemu_slirp_network_api_server_port_forward}-10.0.2.15:6443"
      ]
      : []
    )
    )}'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'-device'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'virtio-net-pci,bus=pci.0,addr=7,netdev=net0'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'-netdev'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'socket,${join(",",
    [
      format("id=multicast%v", count.index),
    ],
    (count.index == 0
      ? [
        "listen=:1234"
      ]
      : [
        "connect=127.0.0.1:1234"
      ]
    ),
    # [
    #   "mcast=230.0.0.1:1234"
    # ]
)}'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'-device'"/>
      </xsl:attribute>
    </xsl:element>
    <xsl:element name="arg" namespace="http://libvirt.org/schemas/domain/qemu/1.0">
      <xsl:attribute name="value">
        <xsl:value-of select="'virtio-net-pci,bus=pci.0,addr=8,${format("netdev=multicast%v", count.index)},mac=${var.controllers[count.index].mac}'"/>
      </xsl:attribute>
    </xsl:element>
    -->
   </xsl:element>
  </xsl:template>
</xsl:stylesheet>
EOF
}

# qemu doesnt support SPICE (default for libvirt terraform provider)
graphics {
  type = "vnc"
}
}