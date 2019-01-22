variable "playbook_location" {
    default = "~/"
}

variable "private_key_location" {
    default = "/home/edebeste/.ssh/id_rsa"
}
variable "public_network" {
    default = "public1"
}

variable "ceph_network" {
    default = "ceph-net"
}
