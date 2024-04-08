packer {
  required_plugins {
    arm-image = {
      version = ">= 0.2.5"
      source  = "github.com/solo-io/arm-image"
    }

    ansible = {
      source = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
  }
}

locals {
  pwn_hostname    = "pwnagotchi"
  pwn_version     = "master"
  python_version  = "3.10.14"
  usr_bin = [
    "bettercap-launcher", "pwnagotchi-launcher", "decryption-webserver", "hdmioff", "hdmion", "monstart", "monstop", "pwnlib"
  ]
  etc_network = [
    "eth0-cfg", "lo-cfg", "usb0-cfg", "wlan0-cfg"
  ]
  etc_systemd = [
    "bettercap.service", "pwnagotchi.service", "pwngrid-peer.service"
  ]
}

source "arm-image" "pwnagotchi" {
  image_type        = "raspberrypi"
  iso_url           = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz"
  iso_checksum      = "sha256:58a3ec57402c86332e67789a6b8f149aeeb4e7bb0a16c9388a66ea6e07012e45"
  output_filename   = "output/pwnagotchi-raspios-lite-2.9.0.iso"
  // qemu_binary       = "/usr/libexec/qemu-binfmt/aarch64-binfmt-P"
  // qemu_binary       = "/usr/bin/qemu-aarch64-static"
  // qemu_binary       = "qemu-aarch64-static"
  image_mounts      = ["/boot/firmware","/"]
  target_image_size = 12*1024*1024*1024
}

build {
  name = "RPi02W64 Pwnagotchi"
  sources = [
    "source.arm-image.pwnagotchi"
  ]

  provisioner "shell" {
    inline = [
      "sed -i 's/^\\([^#]\\)/#\\1/g' /etc/ld.so.preload"
    ]
    valid_exit_codes = [0, 2] # ignore if file does not exist
  }

  provisioner "shell" {
    inline = [
      "dpkg-architecture",
      "apt-get update && apt-get -y full-upgrade",
      "apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev git"
    ]
  }

  provisioner "shell" {
    inline = [
      "wget https://www.python.org/ftp/python/${local.python_version}/Python-${local.python_version}.tgz",
      "tar -xzvf Python-${local.python_version}.tgz",
      "cd Python-${local.python_version}/",
      "./configure --enable-optimizations",
      "make install",
      "rm /usr/bin/python",
      "ln -s /usr/local/bin/python3.10 /usr/bin/python"
    ]
  }

  provisioner "shell" {
    inline = [
      "python -m pip cache purge",
      "python -m pip install --upgrade pip setuptools wheel meson --break-system-packages",
      "python -m pip install https://files.pythonhosted.org/packages/17/90/0849d3708805372d117ab84d1f8282295ee9968138935ef6a863085d4f7e/ansible_core-2.16.5-py3-none-any.whl",
      "ansible-galaxy collection install community.general"
    ]
  }

  dynamic "provisioner" {
    labels = [ "file" ]
    for_each = local.usr_bin
    content {
      source      = "data/usr/bin/${provisioner.value}"
      destination = "/usr/bin/${provisioner.value}"
    }
  }

  dynamic "provisioner" {
    labels = [ "file" ]
    for_each = local.etc_network
    content {
      source      = "data/etc/network/interfaces.d/${provisioner.value}"
      destination = "/etc/network/interfaces.d/${provisioner.value}"
    }
  }

  dynamic "provisioner" {
    labels = [ "file" ]
    for_each = local.etc_systemd
    content {
      source      = "data/etc/systemd/system/${provisioner.value}"
      destination = "/etc/systemd/system/${provisioner.value}"
    }
  }

  provisioner "shell" {
    inline = ["chmod +x /usr/bin/*"]
  }

  provisioner "file" {
    source      = "data/etc/update-motd.d/01-motd"
    destination = "/etc/update-motd.d/01-motd"
  }

  provisioner "shell" {
    inline = ["chmod +x /etc/update-motd.d/*"]
  }

  provisioner "ansible-local" {
    playbook_file   = "pwnagotchi.yml"
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_VERSION=${local.pwn_version} PWN_HOSTNAME=${local.pwn_hostname} ansible-playbook"
    extra_arguments = [
      "--connection=chroot",
      "--become-user=root",
      "--extra-vars \"ansible_python_interpreter=/usr/bin/python\""
    ]
  }

  provisioner "shell" {
    inline = [
      "sed -i 's/^#\\(.+\\)/\\1/g' /etc/ld.so.preload"
    ]
    valid_exit_codes = [0, 2] # ignore if file does not exist
  }
}
