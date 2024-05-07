variable "cibr_block" {
  type    = string
  default = "10.0.0.0/16"
}
variable "availability_zones" {
  type    = string
  default = "us-east-1a"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  type    = string
  default = "ubuntu_key.pem"
}

data "aws_ami" "ubuntu_os" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20240301"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

}