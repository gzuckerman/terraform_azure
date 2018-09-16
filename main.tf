variable "prefix" {
  default = "windows"
}

module "resource_group" {
  source   = "./modules/azure/resource_group/"
  name     = "${var.prefix}-resources"
  location = "West Europe"
}

resource "azurerm_public_ip" "test" {
  name                         = "${var.prefix}-publicIP"
  location                     = "${module.resource_group.resource_group_location}"
  resource_group_name          = "${module.resource_group.resource_group_name}"
  public_ip_address_allocation = "dynamic"

  tags {
    environment = "Staging"
  }
}

module "virtual_network" {
  source              = "./modules/azure/virtual_network/"
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${module.resource_group.resource_group_location}"
  resource_group_name = "${module.resource_group.resource_group_name}"
}

module "subnet" {
  source               = "./modules/azure/subnet/"
  name                 = "internal"
  resource_group_name  = "${module.resource_group.resource_group_name}"
  virtual_network_name = "${module.virtual_network.virtual_network_name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = "${module.resource_group.resource_group_location}"
  resource_group_name = "${module.resource_group.resource_group_name}"

  ip_configuration {
    name                          = "${var.prefix}-ip-configuration"
    subnet_id                     = "${module.subnet.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.test.id}"
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = "${module.resource_group.resource_group_location}"
  resource_group_name   = "${module.resource_group.resource_group_name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2008-R2-SP1"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "Windows"
    admin_username = "AdminPerson"
    admin_password = "Password12345!"
  }

  os_profile_windows_config {
    enable_automatic_upgrades = false
  }

  tags {
    environment = "staging"
  }
}
