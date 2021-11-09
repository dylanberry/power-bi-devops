terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "random" {
}

resource "random_password" "power_bi_devops" {
    length           = 16
    special          = true
    override_special = "_%@"
}

resource "azurerm_resource_group" "power_bi_devops" {
  name     = var.resource_group
  location = var.location
}

## Create an availability set which the VMs will go into using the same location and resource group
resource "azurerm_availability_set" "power_bi_devops" {
  name                = "power-bi-devops-as"
  location            = azurerm_resource_group.power_bi_devops.location
  resource_group_name = azurerm_resource_group.power_bi_devops.name
}

## Create an Azure NSG to protect the infrastructure called nsg.
resource "azurerm_network_security_group" "power_bi_devops" {
  name                = "power-bi-devops-nsg"
  location            = azurerm_resource_group.power_bi_devops.location
  resource_group_name = azurerm_resource_group.power_bi_devops.name
}
  
## Create a rule to allow Ansible to connect to each VM
resource "azurerm_network_security_rule" "allow_win_rm" {
  name                        = "allowWinRm"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefix       = var.ansible_control_node_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.power_bi_devops.name
  network_security_group_name = azurerm_network_security_group.power_bi_devops.name
}

## Create a simple vNet
resource "azurerm_virtual_network" "power_bi_devops" {
  name                = "power-bi-devops-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.power_bi_devops.location
  resource_group_name = azurerm_resource_group.power_bi_devops.name
}

## Create a simple subnet inside of th vNet ensuring the VMs are created first (depends_on)
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.power_bi_devops.name
  virtual_network_name = azurerm_virtual_network.power_bi_devops.name
  address_prefixes     = ["10.0.2.0/24"]

  depends_on = [
    azurerm_virtual_network.power_bi_devops
  ]
}

## You'll need public IPs for each VM for Ansible to connect to and to deploy the web app to.
resource "azurerm_public_ip" "vm" {
  count                   = 2
  name                    = "publicVmIp-${count.index}"
  location                = azurerm_resource_group.power_bi_devops.location
  resource_group_name     = azurerm_resource_group.power_bi_devops.name
  allocation_method       = "Dynamic"
  domain_name_label       = "${var.domain_name_prefix}-${count.index}"
}

## Create a vNic for each VM. Using the count property to create two vNIcs while using ${count.index}
## to refer to each VM which will be defined in an array
resource "azurerm_network_interface" "power_bi_devops" {
  count               = 2
  name                = "power-bi-devops-nic-${count.index}"
  location            = azurerm_resource_group.power_bi_devops.location
  resource_group_name = azurerm_resource_group.power_bi_devops.name
  
  ## Simple ip configuration for each vNic
  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[count.index].id
  }
  
  ## Ensure the subnet is created first before creating these vNics.
  depends_on = [
    azurerm_subnet.internal
  ]
}

## Apply the NSG to each of the VMs' NICs
resource "azurerm_network_interface_security_group_association" "power_bi_devops" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.power_bi_devops[count.index].id
  network_security_group_id = azurerm_network_security_group.power_bi_devops.id
}

## Create the two Windows VMs associating the vNIcs created earlier
resource "azurerm_windows_virtual_machine" "power_bi_devops" {
  count                 = 2
  name                  = "power-bi-devops-vm-${count.index}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.power_bi_devops.name
  size                  = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.power_bi_devops[count.index].id]
  availability_set_id   = azurerm_availability_set.power_bi_devops.id
  computer_name         = "pbidevops-${count.index}"
  admin_username        = var.vm_admin_username
  admin_password        = random_password.power_bi_devops.result
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  depends_on = [
    azurerm_network_interface.power_bi_devops
  ]
}

## Install the custom script VM extension to each VM. When the VM comes up,
## the extension will download the ConfigureRemotingForAnsible.ps1 script from GitHub
## and execute it to open up WinRM for Ansible to connect to it from Azure Cloud Shell.
## exit code has to be 0
resource "azurerm_virtual_machine_extension" "enablewinrm" {
  count                      = 2
  name                       = "enablewinrm"
  virtual_machine_id         = azurerm_windows_virtual_machine.power_bi_devops[count.index].id
  publisher                  = "Microsoft.Compute" ## az vm extension image list --location eastus Do not use Microsoft.Azure.Extensions here
  type                       = "CustomScriptExtension" ## az vm extension image list --location eastus Only use CustomScriptExtension here
  type_handler_version       = "1.9" ## az vm extension image list --location eastus
  auto_upgrade_minor_version = true
  settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
    }
SETTINGS
}

output "vmAnsiblePort" {
  value = azurerm_network_security_rule.allow_win_rm.destination_port_range
}

output "vmUserName" {
  value = var.vm_admin_username
}

output "vmPassword" {
  value       = random_password.power_bi_devops.result
  sensitive   = true
}

output "vmIps" {
  value       = azurerm_public_ip.vm.*.ip_address
}
