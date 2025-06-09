# terraform/main.tf
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.yc_cloud_id
  folder_id                = var.yc_folder_id
  zone                     = var.yc_zone
}

resource "yandex_vpc_network" "default" {
  name = "postgres-network"
}

resource "yandex_vpc_subnet" "default" {
  name           = "postgres-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["10.128.0.0/24"]
}

resource "yandex_compute_instance" "pg_master" {
  name        = "pg-master"
  platform_id = "standard-v1"
  zone        = var.yc_zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.instance_image
      size     = 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.instance_user}:${var.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "pg_standby" {
  name        = "pg-standby"
  platform_id = "standard-v1"
  zone        = var.yc_zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.instance_image
      size     = 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.instance_user}:${var.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "pg_client" {
  name        = "pg-client"
  platform_id = "standard-v1"
  zone        = var.yc_zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.instance_image
      size     = 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.instance_user}:${var.ssh_public_key}"
  }
}
