terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Creating the VPC 

resource "aws_vpc" "tf-project-vpc" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "tf-project-VPC"
  }
}

#creating subnet

resource "aws_subnet" "tf-project-subnet-1a" {
  vpc_id     = aws_vpc.tf-project-vpc.id
  cidr_block = "10.10.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-project-subnet-1A"
  }
}
resource "aws_subnet" "tf-project-subnet2-1a" {
  vpc_id     = aws_vpc.tf-project-vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "tf-project-subnet2-1A"
  }
}
resource "aws_subnet" "tf-project-subnet-1b" {
  vpc_id     = aws_vpc.tf-project-vpc.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-project-subnet-1B"
  }
}
resource "aws_subnet" "tf-project-subnet2-1b" {
  vpc_id     = aws_vpc.tf-project-vpc.id
  cidr_block = "10.10.3.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "tf-project-subnet2-1B"
  }
}

resource "aws_key_pair" "tfkey-key-pair" {
  key_name   = "tfkey-key-pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDUQSLUA1Oxtd2A2wmz58+16EK8lBGpwnfYL0iCquoTd8+GMkC00FasvKkhWGXSM9hLMhMirXqGFeRtPCU1h4OoT+BlwJ1Ys3E8Hh8Hep831VlY6anivpaj7tEjsItFAzade0WjUvprFj5kWA26IC6qP7RAbwXofbOJBRfPKWwD6nvZkjv6TnDtnsNGhnAW3UwvqnTOtmt7eALVa7yc6gQi3SMCSuTpM0sRMKmeG9i29plyapCKIch8okeV/g4gFz9PGSIpz7mcpRtyULlbynaK/H4Gq9V4vJGxk41901KuCvzjW4y/WTODN087VPK+ft/Sl3ZqZQV/19uXE383IngD5A0vbVIQPzLWU8twfhVShnPO3bkRnj+leKXbIXtAYV6LlV8PSoJ6Ia653bOTy/fNSkHUTjhM6XiuwcLHnBTxb5l7N1b/4FLJzs+qX8L93wFIPtd1mfVPCCBvdwE0upEU5+qshD29/MVx06IpUwP2WsVtxVE4fgnkf3aZqZNp85c= 91824@LAPTOP-P0BQ9IJ7"
}

#GATEWAY creation
resource "aws_internet_gateway" "tf-project-IGW" {
  vpc_id = aws_vpc.tf-project-vpc.id

  tags = {
    Name = "tf-project-IGW"
  }
}
#route table

# Route Table

resource "aws_route_table" "tf-project-RT" {
  vpc_id = aws_vpc.tf-project-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-project-IGW.id
  }

  tags = {
    Name = "tf-project-RT"
  }
}
resource "aws_route_table_association" "tf-project-RT-asso-01" {
  subnet_id      = aws_subnet.tf-project-subnet-1a.id
  route_table_id = aws_route_table.tf-project-RT.id
}

resource "aws_route_table_association" "tf-project-RT-asso-03" {
  subnet_id      = aws_subnet.tf-project-subnet-1b.id
  route_table_id = aws_route_table.tf-project-RT.id
}


# Security Group

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.tf-project-vpc.id

  ingress {
    description      = "ssh from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  
  ingress {
    description      = "http from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALLOW_SSH"
  }
}

#launch Template

resource "aws_launch_template" "tf-project-launch-template" {
  name = "tf-project-launch-template"
  image_id = "ami-061ff61aa64acb3b4"
  instance_type = "t2.micro"
  key_name = aws_key_pair.tfkey-key-pair.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "tf-project-asg-instance"
    }
  }

  user_data = filebase64("${path.module}/userdata_file.sh")

}

#ASG

resource "aws_autoscaling_group" "tf-project-ASG" {
  desired_capacity   = 2
  max_size           = 5
  min_size           = 2
  vpc_zone_identifier = [aws_subnet.tf-project-subnet-1a.id,aws_subnet.tf-project-subnet-1b.id]

  launch_template {
    id      = aws_launch_template.tf-project-launch-template.id
    version = "$Latest"
  }
 target_group_arns = [aws_lb_target_group.ASG-TG.arn]
}

#TG with ASG

resource "aws_lb_target_group" "ASG-TG" {
  name     = "ASG-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.tf-project-vpc.id
}

#Listener with ASG

resource "aws_lb_listener" "Asg-listener" {
  load_balancer_arn = aws_lb.Asg-LB.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ASG-TG.arn
  }
}

#load balancer with ASG

resource "aws_lb" "Asg-LB" {
  name               = "Asg-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh.id]
  subnets            = [aws_subnet.tf-project-subnet-1a.id,aws_subnet.tf-project-subnet-1b.id]


  tags = {
    Environment = "production"
  }
}