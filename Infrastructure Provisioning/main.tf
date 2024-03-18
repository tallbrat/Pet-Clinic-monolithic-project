# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create internet gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zones
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

# Create nat gateway
resource "aws_eip" "lb" {
  domain   = "vpc"
  depends_on = [ aws_internet_gateway.my_igw ]
}
resource "aws_nat_gateway" "nat_gw" {
  connectivity_type = "public"
  subnet_id       = aws_subnet.public_subnet.id
  allocation_id   = aws_eip.lb.id
}

# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zones
}

# Create private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_eip.lb.id
  }
}

# Associate private subnet with route table
resource "aws_route_table_association" "public_route_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Create jenkins security group
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.my_vpc.id

    ingress {
      from_port   = [80, 443, 22, 8080]
      to_port     = [80, 443, 22, 8080]
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description      = "Allow HTTP, HTTPS, SSH, Jenkins traffic from anywhere"
    }
    egress = {
      from_port        = [80, 443, 22, 8080]
      to_port          = [80, 443, 22, 8080]
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow HTTP, HTTPS, SSH, Jenkins traffic from anywhere"
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
      description      = "Allow mySql traffic from anywhere"
    }
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description      = "Allow SSH traffic from anywhere"
    }
    egress = {
      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow mySql traffic from anywhere"
    }
}

# Create tomcat-server security group
resource "aws_security_group" "tomcat_sg" {
  vpc_id = aws_vpc.my_vpc.id

    ingress {
      from_port   = [8080, 3306]
      to_port     = [8080, 3306]
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description      = "Allow tomcat and mySql traffic from within the VPC"
    }
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description      = "Allow SSH traffic from anywhere"
    }
    egress = {
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow mySql traffic from anywhere"
    }
}
# Create proxy-server security group
resource "aws_security_group" "proxy_sg" {
  vpc_id = aws_vpc.my_vpc.id

    ingress {
      from_port   = [80, 22]
      to_port     = [80, 22]
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description      = "Allow Nginx and SSH traffic from anywhere"
    }
    egress = {
      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow mySql traffic from anywhere"
    }
}
# Create TLS private key
resource "tls_private_key" "my_tls_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create key pair
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my_key_pair"
  public_key = tls_private_key.my_tls_key.public_key_openssh
}

# Create public EC2 instance
resource "aws_instance" "public_instance" {
  ami             = "attach AMI"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.my_sg.name]

}

# Create DB private EC2 instance
resource "aws_instance" "private_db_instance" {
  ami             = "your_ami_id"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.db_sg.name]
  tags = {
    Name = "MySQL server"
  }
}

# Create Tomcat private EC2 instance
resource "aws_instance" "private_tomcat_instance" {
  ami             = "your_ami_id"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.tomcat_sg.name]
  tags = {
    Name = "tomcat server"
  }
}
# Create Proxy private EC2 instance
resource "aws_instance" "private_proxy_instance" {
  ami             = "your_ami_id"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  key_name        = aws_key_pair.my_key_pair.key_name
  security_groups = [aws_security_group.proxy_sg.name]
  tags = {
    Name = "proxy server"
  }
}