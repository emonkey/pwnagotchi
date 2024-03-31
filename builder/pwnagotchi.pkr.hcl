packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source = "github.com/hashicorp/ansible"
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
  iso_url           = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz"
  iso_checksum      = "sha256:58a3ec57402c86332e67789a6b8f149aeeb4e7bb0a16c9388a66ea6e07012e45"
  output_filename   = "pwnagotchi-raspios-lite-1.5.5.iso"
  target_image_size = 12*1024*1024*1024
}

build {
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
      "apt-get -y update && apt-get -y upgrade",
      "apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev git"
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
      "pip3 install --no-cache-dir ansible meson wheel"
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
    inline = [
      "chmod +x /usr/bin/*"
    ]
  }

  provisioner "ansible-local" {
    playbook_file   = "pwnagotchi.yml"
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_VERSION=${local.pwn_version} PWN_HOSTNAME=${local.pwn_hostname} ansible-playbook"
    extra_arguments = [
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
