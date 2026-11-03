resource "azurerm_resource_group" "k8_rg" {
  name     = "k8s-cluster-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "k8_vnet" {
  name                = "k8-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.k8_rg.location
  resource_group_name = azurerm_resource_group.k8_rg.name
}

resource "azurerm_subnet" "k8_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.k8_rg.name
  virtual_network_name = azurerm_virtual_network.k8_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


# 1. Network Security Group Definition
resource "azurerm_network_security_group" "k8_nsg" {
  name                = "k8-nsg"
  location            = azurerm_resource_group.k8_rg.location
  resource_group_name = azurerm_resource_group.k8_rg.name

  security_rule {
    name                       = "Allow-Required-Ports"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "6443", "80", "443"] # Corrected to plural 'destination_port_ranges'
    source_address_prefix      = "*"                         # Production වලදී ඔබේ IP එකට සීමා කරන්න
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Development"
    project     = "K8s-Lab"
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "k8_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.k8_subnet.id
  network_security_group_id = azurerm_network_security_group.k8_nsg.id
}

# 2. RSA Keys Generation (1 Master + 2 Workers = 3 Keys)
resource "tls_private_key" "rsa_4096_keys" {
  count     = 3
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 3. Master Node public_ip
resource "azurerm_public_ip" "k8_master_public_ip" {
  name                = "k8-master-publicip"
  resource_group_name = azurerm_resource_group.k8_rg.name
  location            = azurerm_resource_group.k8_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "Development"
  }
}

# 4. Master Node Network Interface
resource "azurerm_network_interface" "k8_master_nic" {
  name                = "k8-master-nic"
  location            = azurerm_resource_group.k8_rg.location
  resource_group_name = azurerm_resource_group.k8_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.k8_master_public_ip.id
  }
}

# 4. Master Node Virtual Machine
resource "azurerm_linux_virtual_machine" "k8_master_node" {
  name                            = "k8-master-node"
  resource_group_name             = azurerm_resource_group.k8_rg.name
  location                        = azurerm_resource_group.k8_rg.location
  size                            = "Standard_D4_v5"
  admin_username                  = "adminuser"
  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.k8_master_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.rsa_4096_keys[0].public_key_openssh # Fixed reference typos
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# 5. Worker Nodes Network Interfaces (Count = 2)
resource "azurerm_network_interface" "k8_worker_nic" {
  count               = 2
  name                = "k8-worker-nic-${count.index}"
  location            = azurerm_resource_group.k8_rg.location
  resource_group_name = azurerm_resource_group.k8_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 6. Worker Nodes Virtual Machines (Count = 2)
resource "azurerm_linux_virtual_machine" "k8_worker_node" {
  count                           = 2
  name                            = "k8-worker-node-${count.index}"
  resource_group_name             = azurerm_resource_group.k8_rg.name
  location                        = azurerm_resource_group.k8_rg.location
  size                            = "Standard_D4_v5"
  disable_password_authentication = true
  admin_username                  = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.k8_worker_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.rsa_4096_keys[count.index + 1].public_key_openssh # Uses Key Index 1 and 2
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
