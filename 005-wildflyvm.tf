resource "azurerm_public_ip" "wildfly" {
 name       = "myWildflyPublicIP"
 location   = "${azurerm_resource_group.main.location}"
 resource_group_name  = "${azurerm_resource_group.main.name}"
 allocation_method    = "Dynamic"
 domain_name_label = "adrianwildfly-${formatdate("DDMMYYhhmmss", timestamp())}"

 tags = {
  environment = "staging"
 }
}

resource "azurerm_network_security_group" "wildfly" {
  name = "myWildflyNetworkSecurityGroup"
  location = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {
    name = "SSH"
    priority = 1001
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "HTTP"
    priority = 500
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "HTTPS"
    priority = 450
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "Wildfly"
    priority = 425
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "8080"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "staging"
  }

}

resource "azurerm_network_interface" "wildfly" {
 name			  = "${var.prefix}-wildflynic"
 location		= "${azurerm_resource_group.main.location}"
 resource_group_name	= "${azurerm_resource_group.main.name}"
 network_security_group_id = "${azurerm_network_security_group.wildfly.id}"

 ip_configuration {
   name			= "testconfiguration1"
   subnet_id		= "${azurerm_subnet.internal.id}"
   private_ip_address_allocation = "Dynamic"
    public_ip_address_id  = "${azurerm_public_ip.wildfly.id}"
 }

// depends_on = [azurerm_network_security_group.main, azurerm_subnet.internal, azurerm_public_ip.main]
}


resource "azurerm_virtual_machine" "wildfly" {
 name			= "${var.prefix}-vm"
 location		= "${azurerm_resource_group.main.location}"
 resource_group_name	= "${azurerm_resource_group.main.name}"
 network_interface_ids	= ["${azurerm_network_interface.wildfly.id}"]
 vm_size		= "Standard_B1s"

 storage_image_reference {
   publisher	= "Canonical"
   offer	= "UbuntuServer"
   sku		= "16.04-LTS"
   version	= "latest"
 }

 storage_os_disk {
   name			= "myosdisk1"
   caching		= "ReadWrite"
   create_option	= "FromImage"
   managed_disk_type	= "Standard_LRS"
 }

 os_profile {
   computer_name = "hostname"
   admin_username = "adrian"
 } 

 os_profile_linux_config {
   disable_password_authentication = true
   ssh_keys {
    path = "/home/adrian/.ssh/authorized_keys"
    key_data = "${file("/home/adrian/.ssh/id_rsa.pub")}"
   }
 } 

 tags = {
   environment = "staging"
 }

 provisioner "remote-exec" {
   inline = ["sudo apt update", "sudo apt install git", "git clone https://github.com/Nboaram/WildflyAutomation.git", "cd WildflyAutomation/", "./wildflyInstall.sh -y"]
   connection {
      type = "ssh"
      user =  "adrian"
      private_key = "${file("/home/adrian/.ssh/id_rsa")}"
      host = "${azurerm_public_ip.wildfly.fqdn}"
   }
 }
}




