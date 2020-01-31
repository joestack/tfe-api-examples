variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "type of EC2 instance to provision."
  default     = "t2.small"
}

variable "name" {
  description = "name to pass to Name tag"
  default     = "PROD"
}

variable "key_name" {
  default = "joestack"
}

variable "network_address_space" {
  default = "192.168.0.0/16"
}

