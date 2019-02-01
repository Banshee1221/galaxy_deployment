resource "openstack_networking_secgroup_v2" "secgroup_slurm" {
  name        = "secgroup_slurm"
  description = "My neutron slurm-access security group"
}

resource "openstack_networking_secgroup_v2" "secgroup_general" {
  name        = "secgroup_general"
  description = "My neutron ssh-access security group"
}

resource "openstack_networking_secgroup_v2" "secgroup_galaxy" {
  name        = "secgroup_galaxy"
  description = "My neutron http and https-access security group"
}

module "slurm_rules" {
  source          = "./modules/network_rules/slurm"
  secgroup_id   = "${openstack_networking_secgroup_v2.secgroup_slurm.id}"
}

module "general_rules" {
  source          = "./modules/network_rules/general"
  secgroup_id   = "${openstack_networking_secgroup_v2.secgroup_general.id}"
}

module "galaxy_rules" {
  source          = "./modules/network_rules/galaxy"
  secgroup_id = "${openstack_networking_secgroup_v2.secgroup_galaxy.id}"
}

resource "openstack_compute_keypair_v2" "galaxy-keypair" {
  name = "galaxy-dev-keypair"
}

resource "openstack_networking_network_v2" "network_1" {
    name = "sanbi-net"
    admin_state_up = "true"
}

# resource "openstack_networking_network_v2" "network_2" {
#     name = "combattb_ceph_net"
#     admin_state_up = "true"
# }

resource "openstack_networking_subnet_v2" "subnet_1" {
    name = "combattb_subnet_1"
    network_id = "${openstack_networking_network_v2.network_1.id}"
    cidr = "192.168.70.0/24"
    ip_version = 4
    enable_dhcp = "true"
    allocation_pools = {
        start = "192.168.70.100", 
        end = "192.168.70.120"
    }
    dns_nameservers = ["192.168.2.75", "192.168.2.8"]
}


data "openstack_networking_network_v2" "public_network" {
  name = "${var.public_network}"
}

data "openstack_networking_network_v2" "ceph_network" {
  name = "${var.ceph_network}"
}

resource "openstack_networking_router_v2" "router_1" {
  name                = "galaxy_router"
  admin_state_up      = true
  external_network_id = "${data.openstack_networking_network_v2.public_network.id}"
}


resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = "${openstack_networking_router_v2.router_1.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}

# resource "openstack_networking_router_interface_v2" "router_interface_2" {
#   router_id = "${openstack_networking_router_v2.router_2.id}"
#   subnet_id = "${openstack_networking_subnet_v2.subnet_2.id}"
# }

#resource "openstack_compute_instance_v2" "slurmctl" {
#  name            = "il_slurmctl"
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-B"
#  key_pair        = "pvh"
#  security_groups = ["default", 
#                     "secgroup_ssh1", "secgroup_ntp1", "secgroup_slurm1", "secgroup_http1", "secgroup_slurm_submit1"]
#  user_data       = "#cloud-config\nhostname: il_slurmctl.sanbi.ac.za\nfqdn: il_slurmctl.sanbi.ac.za"
#
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#
#}
#resource "openstack_compute_instance_v2" "freeipa" {
#  name            = "il_freeipa"
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-B"
#  key_pair        = "pvh"
#  security_groups = ["default", "secgroup_ssh1", "secgroup_http1", "secgroup_freeipa1", "secgroup_ntp1"]
#  user_data       = "#cloud-config\nhostname: il_freeipa.sanbi.ac.za\nfqdn: il_freeipa.sanbi.ac.za"
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#}

resource "openstack_compute_floatingip_v2" "floatip_1" {
  pool = "${data.openstack_networking_network_v2.public_network.name}"
}

resource "openstack_compute_instance_v2" "galaxy" {
  name            = "il_galaxy"
  image_id      = "${var.image_id}"
  flavor_name      = "m1.large"
  key_pair        = "${openstack_compute_keypair_v2.galaxy-keypair.name}"
  security_groups = ["default", "secgroup_galaxy", "secgroup_general"]
  user_data       = "#cloud-config\nhostname: ${var.fqdn} \nfqdn: ${var.fqdn}"

  metadata {
    ansible_groups = "galaxy"
  }
  network {
    uuid = "${openstack_networking_network_v2.network_1.id}"
  }

}

resource "openstack_compute_floatingip_associate_v2" "galaxy_fip1" {
  floating_ip = "${openstack_compute_floatingip_v2.floatip_1.address}"
  instance_id = "${openstack_compute_instance_v2.galaxy.id}"

  provisioner "remote-exec" {
    connection {
      user = "ubuntu"
      private_key = "${openstack_compute_keypair_v2.galaxy-keypair.private_key}"
      host = "${openstack_compute_floatingip_v2.floatip_1.address}"
    }
    inline = [
      "sudo apt-get update; sleep 5",
      "sudo apt-get install -y python-minimal python-pip",
      "sudo pip install --upgrade pip",
      "sudo pip install ansible"
    ]
  }

  provisioner "local-exec" {
    command = "python3 inventory_gen.py /home/${var.remote_user}/ansible/host.key > ./ansible/hosts"
  }


  provisioner "file" {
    connection {
      user = "ubuntu"
      private_key = "${openstack_compute_keypair_v2.galaxy-keypair.private_key}"
      host = "${openstack_compute_floatingip_v2.floatip_1.address}"
    }

    source      = "./ansible"
    destination = "/home/${var.remote_user}/"
  }

  provisioner "remote-exec" {
    connection {
      user = "ubuntu"
      private_key = "${openstack_compute_keypair_v2.galaxy-keypair.private_key}"
      host = "${openstack_compute_floatingip_v2.floatip_1.address}"
    }
    inline = [
      "cat <<EOF > /home/ubuntu/ansible/host.key\n${openstack_compute_keypair_v2.galaxy-keypair.private_key}\nEOF"
      ]
  }

  provisioner "remote-exec" {
    connection {
      user = "ubuntu"
      private_key = "${openstack_compute_keypair_v2.galaxy-keypair.private_key}"
      host = "${openstack_compute_floatingip_v2.floatip_1.address}"
    }
    inline = [
      "sudo chmod 0600 /home/${var.remote_user}/ansible/host.key",
      "printf 'Host *\n    StrictHostKeyChecking no' > /home/${var.remote_user}/.ssh/config",
      "ansible-playbook -i /home/${var.remote_user}/ansible/hosts /home/${var.remote_user}/ansible/site.yml",
      "rm -rf /home/${var.remote_user}/ansible/host.key"
    ]
  }
}

#resource "openstack_compute_instance_v2" "slurmwn1" {
#  name            = "il-slurmwn1"
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-C"
#  key_pair        = "pvh"
#  security_groups = ["default", "secgroup_ssh1", "secgroup_ntp1", "secgroup_slurm_submit1"]
#  user_data       = "#cloud-config\nhostname: il-slurmwn1.sanbi.ac.za\nfqdn: il-slurmwn1.sanbi.ac.za"
#
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#}
#
#resource "openstack_compute_instance_v2" "slurmwn2" {
#  name            = "il-slurmwn2"
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-D"
#  key_pair        = "pvh"
#  security_groups = ["default", "secgroup_ssh1", "secgroup_ntp1", "secgroup_slurm_submit1"]
#  user_data       = "#cloud-config\nhostname: il-slurmwn2.sanbi.ac.za\nfqdn: il-slurmwn2.sanbi.ac.za"
#
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#}
#
#resource "openstack_compute_instance_v2" "slurmwn3" {
#  name            = "il-slurmwn3"
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-D"
#  key_pair        = "pvh"
#  security_groups = ["default", "secgroup_ssh1", "secgroup_ntp1", "secgroup_slurm_submit1"]
#  user_data       = "#cloud-config\nhostname: il-slurmwn3.sanbi.ac.za\nfqdn: il-slurmwn3.sanbi.ac.za"
#
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#}
#
#resource "openstack_compute_instance_v2" "slurmwn4" {
#  name            = "il-slurmwn4"
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-D"
#  key_pair        = "pvh"
#  security_groups = ["default", "secgroup_ssh1", "secgroup_ntp1", "secgroup_slurm_submit1"]
#  user_data       = "#cloud-config\nhostname: il-slurmwn4.sanbi.ac.za\nfqdn: il-slurmwn4.sanbi.ac.za"
#
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#}
#
#resource "openstack_compute_instance_v2" "slurmwn5" {
#  name            = "il-slurmwn5"  
#  image_name      = "Ubuntu-xenial-16.04-amd64"
#  flavor_name      = "ilifu-D"
#  key_pair        = "pvh"
#  security_groups = ["default", "secgroup_ssh1", "secgroup_ntp1", "secgroup_slurm_submit1"]
#  user_data       = "#cloud-config\nhostname: il-slurmwn5.sanbi.ac.za\nfqdn: il-slurmwn5.sanbi.ac.za"
#
#  network {
#    name = "${openstack_networking_network_v2.network_1.name}"
#  }
#}
#
#resource "openstack_blockstorage_volume_v2" "clusterstore_1" {
#  name = "clusterstore_1"
#  size = 100
#}
#
#resource "openstack_compute_volume_attach_v2" "va_1" {
#  instance_id = "${openstack_compute_instance_v2.galaxy.id}"
#  volume_id   = "${openstack_blockstorage_volume_v2.clusterstore_1.id}"
#}



#resource "openstack_compute_floatingip_v2" "floatip_2" {
#  pool = "${data.openstack_networking_network_v2.public_network.name}"
#}

#resource "openstack_compute_floatingip_associate_v2" "slurmctl_fip1" {
#  floating_ip = "${openstack_compute_floatingip_v2.floatip_1.address}"
#  instance_id = "${openstack_compute_instance_v2.slurmctl.id}"
#}

#output "slurmctl_ext_ip" {
#  value = "${openstack_compute_floatingip_associate_v2.slurmctl_fip1.floating_ip}"
#}

#output "freeipa_ip" {
#  value = "${openstack_compute_instance_v2.freeipa.network.0.fixed_ip_v4}"
#}

output "galaxy_ip" {
  value = "${openstack_compute_instance_v2.galaxy.network.0.fixed_ip_v4}"
}

output "galaxy_ext_ip" {
  value = "${openstack_compute_floatingip_associate_v2.galaxy_fip1.floating_ip}"
}

#output "slurmwn1_ip" {
#  value = "${openstack_compute_instance_v2.slurmwn1.network.0.fixed_ip_v4}"
#}
#
#output "slurmwn2_ip" {
#  value = "${openstack_compute_instance_v2.slurmwn2.network.0.fixed_ip_v4}"
#}
#
#output "slurmwn3_ip" {
#  value = "${openstack_compute_instance_v2.slurmwn3.network.0.fixed_ip_v4}"
#}
#output "slurmwn4_ip" {
#  value = "${openstack_compute_instance_v2.slurmwn4.network.0.fixed_ip_v4}"
#}
#output "slurmwn5_ip" {
#  value = "${openstack_compute_instance_v2.slurmwn5.network.0.fixed_ip_v4}"
#}
#
# output "slurmwn1_ip" {
#   value = "${openstack_compute_floatingip_associate_v2.fip_2.floating_ip}"
# }

