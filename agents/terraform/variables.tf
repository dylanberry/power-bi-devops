variable "location" {
    type = string
}

variable "resource_group" {
    type = string
}

variable "ansible_control_node_ip" {
    type = string
}

variable "management_ip" {
    type = string
}

variable "domain_name_prefix" {
    type = string
}

variable "vm_admin_username" {
    type = string
    default = "pbiagentadmin"
}
