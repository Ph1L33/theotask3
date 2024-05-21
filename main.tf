terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}



provider "google" {
  # Configuration options
  project = "round-pilot-379103"
  credentials = "round-pilot-379103-ca21d8a9a4e01.json"
}


# European HQ Network and Subnet
resource "google_compute_network" "europe_network" {
  name                    = "europe-network"
  auto_create_subnetworks = false
}


# Europe's subnet to identify it as target for HTTP traffic
resource "google_compute_subnetwork" "europe_subnet" {
  name                     = "europe-subnet"
  network                  = google_compute_network.europe_network.id
  ip_cidr_range            = "10.150.11.0/24"
  region                   = "europe-west1"
  private_ip_google_access = true


}
resource "google_compute_firewall" "europe_http" {
  name    = "europe-http"
  network = google_compute_network.europe_network.id


  allow {
    protocol = "tcp"
    ports    = ["80"]
  }


  source_ranges = ["10.150.11.0/24", "172.16.20.0/24", "172.16.21.0/24", "192.168.11.0/24"]
  target_tags   = ["europe-http-server", "america-http-server", "asia-rdp-server"]
}




resource "google_compute_instance" "europe_vm" {
  depends_on   = [google_compute_subnetwork.europe_subnet]
  name         = "europe-vm"
  machine_type = "e2-medium"
  zone         = "europe-west1-b"


  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }


  network_interface {
    network    = google_compute_network.europe_network.id
    subnetwork = google_compute_subnetwork.europe_subnet.id


    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }


  metadata = {
    startup-script = file("${path.module}/startup.sh")
  }


  service_account {
    scopes = ["cloud-platform"]
  }


  tags = ["europe-http-server"]


}










# Americas Networks and Subnets
resource "google_compute_network" "americas_network" {
  name                    = "americas-network"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "americas_subnet1" {
  name                     = "americas-subnet1"
  network                  = google_compute_network.americas_network.id
  ip_cidr_range            = "172.16.20.0/24"
  region                   = "us-west1"
  private_ip_google_access = true
}


resource "google_compute_subnetwork" "americas_subnet2" {
  name                     = "americas-subnet2"
  network                  = google_compute_network.americas_network.id
  ip_cidr_range            = "172.16.21.0/24"
  region                   = "us-east1"
  private_ip_google_access = true
}


resource "google_compute_firewall" "america_to_europe_http" {
  name    = "america-to-europe-http"
  network = google_compute_network.americas_network.id


  allow {
    protocol = "tcp"
    ports    = ["80", "22", "3389"]
  }


  source_ranges = ["0.0.0.0/0", "35.235.240.0/20"]
  target_tags   = ["america-http-server", "iap-ssh-allowed"]


}




resource "google_compute_instance" "america_vm1" {
  depends_on   = [google_compute_subnetwork.americas_subnet1]
  name         = "america-vm1"
  machine_type = "e2-medium"
  zone         = "us-west1-a"


  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }


  network_interface {
    network    = google_compute_network.americas_network.id
    subnetwork = google_compute_subnetwork.americas_subnet1.id


    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }


  tags = ["america-http-server", "iap-ssh-allowed"]


}


resource "google_compute_instance" "america_vm2" {
  depends_on   = [google_compute_subnetwork.americas_subnet2]
  name         = "america-vm2"
  machine_type = "n2-standard-4"
  zone         = "us-east1-b"


  boot_disk {
    initialize_params {
      image = "projects/windows-cloud/global/images/windows-server-2022-dc-v20240415"
    }
  }


  network_interface {
    network    = google_compute_network.americas_network.id
    subnetwork = google_compute_subnetwork.americas_subnet2.id


    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }


  tags = ["america-http-server"]


}


#VPC Peering for Americas and Europe


resource "google_compute_network_peering" "america_europe_peering" {
  name         = "america-to-europe-peering"
  network      = google_compute_network.americas_network.id
  peer_network = google_compute_network.europe_network.id
}


resource "google_compute_network_peering" "europe_america_peering" {
  name         = "europe-to-america-peering"
  network      = google_compute_network.europe_network.id
  peer_network = google_compute_network.americas_network.id
}


# Asia-Pacific Network and Subnet
resource "google_compute_network" "asia_network" {
  name                    = "asia-network"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "asia_subnet" {
  name                     = "asia-subnet"
  network                  = google_compute_network.asia_network.id
  ip_cidr_range            = "192.168.11.0/24"
  region                   = "asia-northeast1"
  private_ip_google_access = true
}


# Firewall Rule for allowing RDP only from Asia
resource "google_compute_firewall" "asia_allow_rdp" {
  name    = "asia-allow-rdp"
  network = google_compute_network.asia_network.id


  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }


  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["asia-rdp-server"]
}




resource "google_compute_instance" "asia_vm1" {
  depends_on   = [google_compute_subnetwork.asia_subnet]
  name         = "asia-vm"
  machine_type = "n2-standard-4"
  zone         = "asia-northeast1-c"


  boot_disk {
    initialize_params {
      image = "projects/windows-cloud/global/images/windows-server-2022-dc-v20240415"
    }
  }


  network_interface {
    network    = google_compute_network.asia_network.id
    subnetwork = google_compute_subnetwork.asia_subnet.id


    # Ensuring no public IP is assigned
    access_config {
      //  Not assigned a public IP
    }
  }


  tags = ["asia-rdp-server"]


}


# VPN Gateway for Europe
resource "google_compute_vpn_gateway" "europe_vpn_gateway" {
  name    = "europe-vpn-gateway"
  network = google_compute_network.europe_network.id
  region  = "europe-west1"
}


# VPN Gateway for Asia
resource "google_compute_vpn_gateway" "asia_vpn_gateway" {
  name    = "asia-vpn-gateway"
  network = google_compute_network.asia_network.id
  region  = "asia-northeast1"
}


# External Static IP Addresses for VPN Gateways
resource "google_compute_address" "europe_vpn_ip" {
  name   = "europe-vpn-ip"
  region = "europe-west1"
}


resource "google_compute_address" "asia_vpn_ip" {
  name   = "asia-vpn-ip"
  region = "asia-northeast1"
}




# VPN Tunnel from Asia to Europe
data "google_secret_manager_secret_version" "vpn_secret" {
  secret  = "vpn-shared-secret"
  version = "latest"
}


resource "google_compute_vpn_tunnel" "asia_to_europe_tunnel" {
  name               = "asia-to-europe-tunnel"
  region             = "asia-northeast1"
  target_vpn_gateway = google_compute_vpn_gateway.asia_vpn_gateway.id
  peer_ip            = google_compute_address.europe_vpn_ip.address
  shared_secret      = data.google_secret_manager_secret_version.vpn_secret.secret_data
  ike_version        = 2


  local_traffic_selector  = ["192.168.11.0/24"]
  remote_traffic_selector = ["10.150.11.0/24"]


  depends_on = [
    google_compute_forwarding_rule.asia_esp,
    google_compute_forwarding_rule.asia_udp500,
    google_compute_forwarding_rule.asia_udp4500
  ]
}


# Route for Asia to Europe
resource "google_compute_route" "asia_to_europe_route" {
  name                = "asia-to-europe-route"
  network             = google_compute_network.asia_network.id
  dest_range          = "10.150.11.0/24"
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.asia_to_europe_tunnel.id
  priority            = 1000
}




# Forwarding Rules for the Asia VPN
resource "google_compute_forwarding_rule" "asia_esp" {
  name        = "asia-esp"
  region      = "asia-northeast1"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.asia_vpn_ip.address
  target      = google_compute_vpn_gateway.asia_vpn_gateway.self_link
}


resource "google_compute_forwarding_rule" "asia_udp500" {
  name        = "asia-udp500"
  region      = "asia-northeast1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.asia_vpn_ip.address
  port_range  = "500"
  target      = google_compute_vpn_gateway.asia_vpn_gateway.self_link
}


resource "google_compute_forwarding_rule" "asia_udp4500" {
  name        = "asia-udp4500"
  region      = "asia-northeast1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.asia_vpn_ip.address
  port_range  = "4500"
  target      = google_compute_vpn_gateway.asia_vpn_gateway.self_link
}


# Reverse VPN Tunnel from Europe to Asia
resource "google_compute_vpn_tunnel" "europe_to_asia_tunnel" {
  name               = "europe-to-asia-tunnel"
  region             = "europe-west1"
  target_vpn_gateway = google_compute_vpn_gateway.europe_vpn_gateway.id
  peer_ip            = google_compute_address.asia_vpn_ip.address
  shared_secret      = data.google_secret_manager_secret_version.vpn_secret.secret_data
  ike_version        = 2


  local_traffic_selector  = ["10.150.11.0/24"]
  remote_traffic_selector = ["192.168.11.0/24"]


  depends_on = [
    google_compute_forwarding_rule.europe_esp,
    google_compute_forwarding_rule.europe_udp500,
    google_compute_forwarding_rule.europe_udp4500
  ]
}


# Route for Europe to Asia
resource "google_compute_route" "europe_to_asia_route" {
  depends_on          = [google_compute_vpn_tunnel.europe_to_asia_tunnel]
  name                = "europe-to-asia-route"
  network             = google_compute_network.europe_network.id
  dest_range          = "192.168.11.0/24"
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.europe_to_asia_tunnel.id
}


# Forwarding Rules for Europe VPN
resource "google_compute_forwarding_rule" "europe_esp" {
  name        = "europe-esp"
  region      = "europe-west1"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.europe_vpn_ip.address
  target      = google_compute_vpn_gateway.europe_vpn_gateway.self_link
}


resource "google_compute_forwarding_rule" "europe_udp500" {
  name        = "europe-udp500"
  region      = "europe-west1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.europe_vpn_ip.address
  port_range  = "500"
  target      = google_compute_vpn_gateway.europe_vpn_gateway.self_link
}


resource "google_compute_forwarding_rule" "europe_udp4500" {
  name        = "europe-udp4500"
  region      = "europe-west1"
  ip_protocol = "UDP"
  ip_address  = google_compute_address.europe_vpn_ip.address
  port_range  = "4500"
  target      = google_compute_vpn_gateway.europe_vpn_gateway.self_link
}




# Outputs
output "europe_vpn_ip_address" {
  value = google_compute_address.europe_vpn_ip.address
}


output "asia_vpn_ip_address" {
  value = google_compute_address.asia_vpn_ip.address
}


output "europe_vm_internal_ip" {
  description = "Internal IP address of the Europe VM"
  value       = google_compute_instance.europe_vm.network_interface[0].network_ip
}







