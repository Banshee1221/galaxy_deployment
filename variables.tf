variable "playbook_location" {
    default = "~/"
}

variable "image_id" {
    default = "5374bb4f-ae2f-4ed9-a49e-1319bd4feca5"  
}

variable "openstack_keypair" {
    default = "Eugene laptop" #set this to a key that is accessible on the machine you're running this terraform on
}

variable "fqdn" {
    default = "galaxym.sanbi.ac.za"
}

variable "private_key_location" {
    default = "/home/edebeste/.ssh/id_rsa" #set this to the key on your machine that matches the one under "openstack_keypair"
}
variable "public_network" {
    default = "public1"
}

variable "ceph_network" {
    default = "ceph-net"
}
