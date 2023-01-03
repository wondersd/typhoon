# libvirt terraform provider doesnt support decompressing source urls
# https://github.com/dmacvicar/terraform-provider-libvirt/issues/653
# tried to co-op the storage pool location, but this causes errors when deleting the storage pool
resource "null_resource" "coreos" {
  provisioner "local-exec" {
    interpreter = [
      "/bin/bash",
      "-ce"
    ]
    command = <<EOF
if [[ -e "${format("%[1]v/fedora-coreos-%[2]v-%[4]v.%[3]v.%[5]v",
    path.module,
    var.os_version,
    "x86_64",
    "qemu",
    "qcow2")}" ]]; then
  exit 0;
fi
curl ${format("https://builds.coreos.fedoraproject.org/prod/streams/%[1]v/builds/%[2]v/%[3]v/fedora-coreos-%[2]v-%[4]v.%[3]v.%[5]v",
    var.os_stream,
    var.os_version,
    "x86_64",
    "qemu",
  "qcow2.xz")
  } | xz --decompress --stdout > ${format("%[1]v/fedora-coreos-%[2]v-%[4]v.%[3]v.%[5]v",
    path.module,
    var.os_version,
    "x86_64",
    "qemu",
"qcow2")}
EOF
}
}

resource "libvirt_volume" "coreos" {
  name = "coreos"
  pool = libvirt_pool.this.name
  source = format("%[1]v/fedora-coreos-%[2]v-%[4]v.%[3]v.%[5]v",
    path.module,
    var.os_version,
    "x86_64",
    "qemu",
  "qcow2")
  format = "qcow2"
  depends_on = [
    null_resource.coreos
  ]
}
