terraform {
  required_version = ">= 1.5.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.0.116:8006"
  # Авторизация через API-токен (рекомендуется)
  api_token = "api@pve!api=78451c6d-ae9b-459f-908e-6054ffc7204a"
  # Отключить проверку SSL, если используется самоподписанный сертификат
  insecure  = true

  ssh {
    agent = false
    username    = "root"
    private_key = file("~/.ssh/id_rsa")
  }


}

# 1. Скачиваем образ на хранилище Proxmox (например, в local)
#resource "proxmox_download_file" "ubuntu_cloud_image" {
#  content_type = "import" # Важно: тип контента для импорта дисков
#  datastore_id = "loal-lvm-thin"
#  node_name    = "proxmox"
#  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
#  # Переименовываем в .qcow2, чтобы Proxmox правильно определил формат
#  file_name    = "jammy-server-cloudimg-amd64.qcow2"
#}

# Загрузка файла Cloud-Init в хранилище Proxmox (обычно 'local')
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox" # Имя вашего узла Proxmox

  source_raw {
    data      = file("${path.module}/cloud-config.yaml")
    file_name = "user-data-qemu.yaml"
  }
}


resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = "test-vm-01"
  node_name = "proxmox" # Имя вашей ноды в Proxmox


network_device {
    bridge = "vmbr0"
  }

  agent {
    timeout = "10s"
    enabled = true
  }

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }
  memory {
    dedicated = 2048
  }


# Блок disk отвечает за основный диск
  disk {
    datastore_id = "loal-lvm-thin" # Хранилище, где будет создан диск ВМ
    import_from = "local:import/jammy-server-cloudimg-amd64.qcow2"
    interface    = "virtio0"   # Интерфейс диска (virtio, scsi, sata, ide)
    size         = 15          # Размер в ГБ (опционально)
  }
 

  initialization {

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "ubuntu"
      keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMuGuk/pWne2gae3AV7TA6fmHzTClHxHcSvjEJ987jwq mitrofanov" ]
    }
  }
}