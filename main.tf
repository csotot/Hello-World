#### Terraform
terraform {
  required_version = ">= 0.13"
}

provider "aws" {
  region  = "eu-west-1"
  profile = "MY-PROFILE"
}

#### Variables
variable "candidate_name" {
  description = "Please input your first and last name:"
  type        = string
  validation {
    condition     = length(var.candidate_name) > 3 && length(var.candidate_name) < 50
    error_message = "The candidate name must be between 3 and 50 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z]+$", var.candidate_name))
    error_message = "The candidate_name must be lower case, and no spaces. For example JohnDoe"
  }
}

#### VPC
resource "aws_vpc" "SEVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "environment" = "se-assignment"
    "Name"        = "SEVPC-${var.candidate_name}"
  }
}

#### Subnets
resource "aws_subnet" "PublicSubnetA" {
  vpc_id            = aws_vpc.SEVPC.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    "environment" = "se-assignment"
    "Name"        = "PublicSubnetA-${var.candidate_name}"
  }
}

resource "aws_subnet" "PublicSubnetB" {
  vpc_id                     = aws_vpc.SEVPC.id
  cidr_block                 = "10.0.1.0/24"
  map_public_ip_on_launch    = true
  availability_zone          = "eu-west-1b"

  tags = {
    Name        = "${var.candidate_name}-PublicSubnetB"
    environment = "se-assignment"
  }
}


resource "aws_subnet" "PrivateSubnetA" {
  vpc_id                     = aws_vpc.SEVPC.id
  cidr_block                 = "10.0.2.0/24"
  availability_zone          = "eu-west-1a"

  tags = {
    Name        = "${var.candidate_name}-PrivateSubnetA"
    environment = "se-assignment"
  }
}


resource "aws_subnet" "PrivateSubnetB" {
  vpc_id                     = aws_vpc.SEVPC.id
  cidr_block                 = "10.0.3.0/24"
  availability_zone          = "eu-west-1b"

  tags = {
    Name        = "${var.candidate_name}-PrivateSubnetB"
    environment = "se-assignment"
  }
}



#### IGW
resource "aws_internet_gateway" "SEIGW" {
  vpc_id = aws_vpc.SEVPC.id

  tags = {
    "environment" = "se-assignment"
    "Name"        = "IGW-${var.candidate_name}"
  }
}

#### NACL
resource "aws_network_acl" "SENetworkACL" {
  vpc_id = aws_vpc.SEVPC.id

  tags = {
    "environment" = "se-assignment"
    "Name"        = "NACL-${var.candidate_name}"
  }
}


#### Route Table
resource "aws_route_table" "SERoutePublic" {
  vpc_id = aws_vpc.SEVPC.id

  tags = {
    Name        = "${var.candidate_name}-PublicRoute"
    environment = "se-assignment"
  }
}

resource "aws_route_table" "SERoutePrivate" {
  vpc_id = aws_vpc.SEVPC.id

  tags = {
    Name        = "${var.candidate_name}-PrivateRoute"
    environment = "se-assignment"
  }
}


#### EC2 Instance
resource "aws_network_interface" "eni_instance1" {
  subnet_id       = aws_subnet.PublicSubnetA.id
  security_groups = [aws_security_group.SESGapp.id]
  description     = "Primary network interface for Instance 1"
}

resource "aws_instance" "SEInstance1" {
  ami                          = "ami-047bb4163c506cd98"
  instance_type                = "t2.micro"
  disable_api_termination      = false
  instance_initiated_shutdown_behavior = "stop"
  monitoring                   = false

  network_interface {
    network_interface_id = aws_network_interface.eni_instance1.id
    device_index         = 0
  }

  tags = {
    Name = "Instance1-${var.candidate_name}"
    environment = "se-assignment"
  }

  user_data_base64 = "IyEvYmluL2Jhc2gKeXVtIHVwZGF0ZSAteQp5dW0gaW5zdGFsbCAteSBodHRwZDI0CnNlcnZpY2UgaHR0cGQgc3RhcnQKY2hrY29uZmlnIGh0dHBkIG9uCmdyb3VwYWRkIHd3dwp1c2VybW9kIC1hIC1HIHd3dyBlYzItdXNlcgpjaG93biAtUiByb290Ond3dyAvdmFyL3d3dwpjaG1vZCAyNzc1IC92YXIvd3d3CmZpbmQgL3Zhci93d3cgLXR5cGUgZCAtZXhlYyBjaG1vZCAyNzc1IHt9ICsKZmluZCAvdmFyL3d3dyAtdHlwZSBmIC1leGVjIGNobW9kIDA2NjQge30gKwplY2hvICc8aHRtbD48aGVhZD48dGl0bGU+U3VjY2VzcyE8L3RpdGxlPjwvaGVhZD48Ym9keT48aWZyYW1lIHdpZHRoPSI1NjAiIGhlaWdodD0iMzE1IiBzcmM9Imh0dHBzOi8vd3d3LnlvdXR1YmUuY29tL2VtYmVkLzJ4N3J0VUx5d3ZFIiBmcmFtZWJvcmRlcj0iMCIgYWxsb3dmdWxsc2NyZWVuPjwvaWZyYW1lPjwvYm9keT48L2h0bWw+JyA+IC92YXIvd3d3L2h0bWwvZGVtby5odG1s"
}



#### ELB
resource "aws_elb" "SEelb" {
  name               = "${var.candidate_name}-elb"
  subnets            = [aws_subnet.PublicSubnetB.id]
  security_groups    = [aws_security_group.SESGELB.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:443"
    interval            = 15
  }

  instances                   = [aws_instance.SEInstance1.id]

  tags = {
    Name        = "${var.candidate_name}-ELB"
    environment = "se-assignment"
  }
}


#### Security Groups
resource "aws_security_group" "SESGELB" {
  name        = "SESGELB"
  description = "SE Assignment - ELB security group"
  vpc_id      = aws_vpc.SEVPC.id

  tags = {
    Name        = "ELBSecurityGroup"
    environment = "se-assignment"
  }
}

resource "aws_security_group" "SESGapp" {
  name        = "SESGapp"
  description = "SE Assignment - App server security group"
  vpc_id      = aws_vpc.SEVPC.id

  tags = {
    Name        = "AppServerSecurityGroup"
    environment = "se-assignment"
  }
}


#### Network ACL Entries
resource "aws_network_acl_rule" "SENetworkACLEntry1" {
  network_acl_id = aws_network_acl.SENetworkACL.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "SENetworkACLEntry2" {
  network_acl_id = aws_network_acl.SENetworkACL.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

#### Subnet Network ACL Association
resource "aws_network_acl_association" "subnetacl1" {
  subnet_id      = aws_subnet.PublicSubnetA.id
  network_acl_id = aws_network_acl.SENetworkACL.id
}

resource "aws_network_acl_association" "subnetacl2" {
  subnet_id      = aws_subnet.PublicSubnetB.id
  network_acl_id = aws_network_acl.SENetworkACL.id
}

resource "aws_network_acl_association" "subnetacl3" {
  subnet_id      = aws_subnet.PrivateSubnetA.id
  network_acl_id = aws_network_acl.SENetworkACL.id
}

resource "aws_network_acl_association" "subnetacl4" {
  subnet_id      = aws_subnet.PrivateSubnetB.id
  network_acl_id = aws_network_acl.SENetworkACL.id
}

#### Route Table Associations
resource "aws_route_table_association" "subnetRoutePublicA" {
  subnet_id      = aws_subnet.PublicSubnetA.id
  route_table_id = aws_route_table.SERoutePublic.id
}

resource "aws_route_table_association" "subnetRoutePublicB" {
  subnet_id      = aws_subnet.PublicSubnetB.id
  route_table_id = aws_route_table.SERoutePublic.id
}

resource "aws_route_table_association" "subnetRoutePrivateA" {
  subnet_id      = aws_subnet.PrivateSubnetA.id
  route_table_id = aws_route_table.SERoutePrivate.id
}

resource "aws_route_table_association" "subnetRoutePrivateB" {
  subnet_id      = aws_subnet.PrivateSubnetB.id
  route_table_id = aws_route_table.SERoutePrivate.id
}


#### Route
resource "aws_route" "publicroute" {
  route_table_id         = aws_route_table.SERoutePublic.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.SEIGW.id
}


#### Output
output "LoadBalancerDNSName" {
  description = "The DNSName of the load balancer"
  value       = aws_elb.SEelb.dns_name
}
