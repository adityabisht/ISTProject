
#AWS Provider

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}


# Creating a Virtual Private Cloud and thne creating resources inside that VPC.

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

# Creating an internet gateway to give the subnet access to the open internet

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

# Give the VPC internet access on its main route table

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.internet-gateway.id}"
}

# Create a subnet to launch  instances into.

resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "Public"
  }
}

# Default security group to access
# instances over SSH and HTTP


resource "aws_security_group" "default" {
  name        = "terraform_securitygroup"
  description = "Used for public instances"
  vpc_id      = "${aws_vpc.vpc.id}"

  # Gives SSH Keys so to access into the EC2 instance.

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "web" {
  instance_type = "t2.micro"
  ami = "ami-fce3c696"

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

 
  subnet_id = "${aws_subnet.default.id}"

  # The connection block tells our provisioner how to
  # communicate with the instance


  connection {
    user = "ubuntu"
  }

  # We run a remote provisioner on the instance after creating it 
  # to install Nginx. 

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start"
    ]
  }
}


