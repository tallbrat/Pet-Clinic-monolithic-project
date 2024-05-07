locals {
  vpc_subnet_ip = cidrsubnets(var.cibr_block, 8, 8, 8, 8, 8)
}
# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.cibr_block
}

# Create internet gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = local.vpc_subnet_ip[1]
  availability_zone       = var.availability_zones
  map_public_ip_on_launch = true
}

# Create route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# Associate public subnet with route table
resource "aws_route_table_association" "public_route_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
/*
resource "aws_network_interface" "single-ip" {
  subnet_id   = aws_subnet.main.id
  private_ips = ["10.0.0.10", "10.0.0.11"]
}
*/
# Create nat gateway
resource "aws_eip" "lb" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.my_igw]
}
resource "aws_nat_gateway" "nat_gw" {
  depends_on        = [aws_eip.lb]
  connectivity_type = "public"
  subnet_id         = aws_subnet.public_subnet.id
  allocation_id     = aws_eip.lb.id
}

# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = local.vpc_subnet_ip[2]
  availability_zone = var.availability_zones
}

# Create private route table
resource "aws_route_table" "private_rt" {
  depends_on = [aws_eip.lb, aws_nat_gateway.nat_gw]
  vpc_id     = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

# Associate private subnet with route table
resource "aws_route_table_association" "private_route_assoc" {
  depends_on     = [aws_route_table.private_rt, aws_subnet.private_subnet]
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Create jenkins security group
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.my_vpc.id


  dynamic "ingress" {
    for_each = toset(["80", "443", "22", "8080"])
    content {
      from_port   = ingress.key
      to_port     = ingress.key
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP, HTTPS, SSH, Jenkins traffic from anywhere"
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP, HTTPS, SSH, Jenkins traffic from anywhere"
  }
}

# Create db-server security group
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow mySql traffic from within the cluster"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH traffic from anywhere"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow mySql traffic from anywhere"
  }
}

# Create tomcat-server security group
resource "aws_security_group" "tomcat_sg" {
  vpc_id = aws_vpc.my_vpc.id
  dynamic "ingress" {
    for_each = toset(["8080", "3306"])
    content {
      from_port   = ingress.key
      to_port     = ingress.key
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allow tomcat and mySql traffic from within the VPC"
    }
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH traffic from anywhere"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP, HTTPS, SSH, Jenkins traffic from anywhere"
  }
}
# Create proxy-server security group
resource "aws_security_group" "proxy_sg" {
  vpc_id = aws_vpc.my_vpc.id
  dynamic "ingress" {
    for_each = toset(["80", "22"])
    content {
      from_port   = ingress.key
      to_port     = ingress.key
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow Nginx and SSH traffic from anywhere"
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow mySql traffic from anywhere"
  }
}
# Create TLS private key
resource "tls_private_key" "my_tls_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create key pair
resource "aws_key_pair" "my_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.my_tls_key.public_key_openssh
}

#Save PEM file locally
resource "local_file" "private_key_pem" {
  filename = var.key_name
  content  = tls_private_key.my_tls_key.private_key_openssh
/*
  provisioner "local-exec" {
    command = "chmod 400 ${var.key_name}"
  }
*/
}

# Create public EC2 instance
resource "aws_instance" "public_instance" {
  ami             = data.aws_ami.ubuntu_os.id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.public_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.public_sg.id]

}

# Create DB private EC2 instance
resource "aws_instance" "private_db_instance" {
  ami             = data.aws_ami.ubuntu_os.id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.db_sg.id]
  tags = {
    Name = "MySQL server"
  }
}

# Create Tomcat private EC2 instance
resource "aws_instance" "private_tomcat_instance" {
  ami             = data.aws_ami.ubuntu_os.id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.tomcat_sg.id]
  tags = {
    Name = "tomcat server"
  }
}
# Create Proxy private EC2 instance
resource "aws_instance" "private_proxy_instance" {
  ami             = data.aws_ami.ubuntu_os.id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.proxy_sg.id]
  tags = {
    Name = "proxy server"
  }
}

data "template_file" "inventory" {
  depends_on = [aws_instance.public_instance, aws_instance.private_tomcat_instance, aws_instance.private_proxy_instance, aws_instance.private_db_instance]
  template   = <<-EOT
    [web_servers]
    ${aws_instance.public_instance.public_ip} ansible_user=ubuntu ansible_private_key_file=${path.module}/${var.key_name}.ppk
    [tomcat_servers]
    ${aws_instance.private_tomcat_instance.private_ip} ansible_user=ubuntu ansible_private_key_file=${path.module}/${var.key_name}.ppk
    [db_servers]
    ${aws_instance.private_db_instance.private_ip} ansible_user=ubuntu ansible_private_key_file=${path.module}/${var.key_name}.ppk
    [proxy_servers]
    ${aws_instance.private_proxy_instance.private_ip} ansible_user=ubuntu ansible_private_key_file=${path.module}/${var.key_name}.ppk
    
    # Add other instances as needed
  EOT
}
#save the inventory template to dynamic_inventory.ini in local
resource "local_file" "dynamic_inventory" {
  depends_on = [data.template_file.inventory]

  filename = "dynamic_inventory.ini"
  content  = data.template_file.inventory.rendered
/*
  provisioner "local-exec" {
    command = "chmod 400 ${local_file.dynamic_inventory.filename}"
  }
*/
}

resource "null_resource" "copy_file" {
  # This triggers the resource when the instance creation is completed
  triggers = {
    instance_ids = aws_instance.public_instance.id
  }
/*
  # Use provisioners to copy files to the instances
  provisioner "local-exec" {
    command = <<EOT
      # Use any command-line tool to copy files, like SCP or rsync
      scp -i ${path.module}/${var.key_name}.ppk ${path.module}/playbooks/* ubuntu@${aws_instance.public_instance.public_ip}:/home/ubuntu/
    EOT
  }
*/
}

# Run Ansible playbook after infrastructure provisioning
resource "null_resource" "run_ansible" {
  depends_on = [local_file.dynamic_inventory]

  provisioner "local-exec" {
    command     = "ansible-playbook -i ${path.module}/dynamic_inventory.ini all_tools_jenkins-server.yml"
    working_dir = path.module
  }
}

