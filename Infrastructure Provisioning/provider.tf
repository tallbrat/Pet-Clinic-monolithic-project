terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.46.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "local" {}
provider "aws" {
  region = "us-east-1"
}
provider "tls" {}
provider "template" {}
provider "null" {}