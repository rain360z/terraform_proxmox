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
}

# 1. Скачиваем образ на хранилище Proxmox (например, в local)
resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "import" # Важно: тип контента для импорта дисков
  datastore_id = "loal-lvm-thin"
  node_name    = "proxmox"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  # Переименовываем в .qcow2, чтобы Proxmox правильно определил формат
  file_name    = "jammy-server-cloudimg-amd64.qcow2"
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = "test-vm-01"
  node_name = "proxmox" # Имя вашей ноды в Proxmox

  agent {
    enabled = false
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
    import_from  = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"   # Интерфейс диска (virtio, scsi, sata, ide)
    size         = 15          # Размер в ГБ (опционально)
  }


  network_device {
    bridge = "vmbr0"
  }
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      username = "ubuntu"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAxZquJg3tsYN6XfWWyfjTiThvXLsX1HkUmHIKeLYJDc mitrofanov-am@MacBook-Air-Mitrofanov-AM.local-2025-12-16"]
    }
  }
}