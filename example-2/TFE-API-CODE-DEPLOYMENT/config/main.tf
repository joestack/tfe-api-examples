provider "aws" {
  region = var.aws_region
}

# INSTANCES #

resource "aws_instance" "jumphost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  availability_zone           = "${var.aws_region}a"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = "192.168.1.100"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.jumphost.id]
  key_name                    = var.key_name

  tags = {
    Name = var.name
  }
}

# Jumphost security group

resource "aws_security_group" "jumphost" {
  name   = "jumphost"
  vpc_id = aws_vpc.hashicorp.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NETWORKING #

resource "aws_vpc" "hashicorp" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

  tags = {
    Name = "${var.name} VPC"
  }
}

resource "aws_subnet" "dmz_subnet" {
  vpc_id                  = aws_vpc.hashicorp.id
  cidr_block              = cidrsubnet(var.network_address_space, 8, 1)
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "DMZ Subnet"
  }
}

# ROUTING #

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hashicorp.id
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.hashicorp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-IGW"
  }
}

resource "aws_route_table_association" "dmz-subnet" {
  subnet_id      = aws_subnet.dmz_subnet.*.id[0]
  route_table_id = aws_route_table.rtb.id
}

