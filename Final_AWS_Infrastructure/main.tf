# Create a AWS Provider 

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}


data "aws_availability_zones" "available" {}

# Create a Virtual Private Cloud

resource "aws_vpc" "vpc" {
  cidr_block = "10.1.0.0/16"
}

# Create an Internet Gateway to give the subnet access to the open internet gateway.

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

# Creating 2 Route Tables. One public and One Private.
# Give the VPC internet access on its public route table and open it to the internet using 0.0.0.0/0

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
  tags {
    Name = "public"
  }
}

resource "aws_default_route_table" "private" {
  default_route_table_id = "${aws_vpc.vpc.default_route_table_id}"
  tags {
    Name = "private"
  }
}


#Create 3 Subnets. One public and 2 private Subnets.

resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "public"
  }
}


resource "aws_subnet" "private1" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.1.2.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "private1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.1.3.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "private2"
  }
}


# Create 3 additional Private Subnets for Relational Database instance.

resource "aws_subnet" "rds1" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.1.4.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "rds1"
  }
}

resource "aws_subnet" "rds2" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.1.5.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "rds2"
  }
}


resource "aws_subnet" "rds3" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.1.6.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "rds3"
  }
}


# Create Subnet Association Rules for RDS subnets and Non RDS Subnets.

resource "aws_route_table_association" "public_assoc" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private1_assoc" {
  subnet_id = "${aws_subnet.private1.id}"
  route_table_id = "${aws_route_table.public.id}"
}


resource "aws_route_table_association" "private2_assoc" {
  subnet_id = "${aws_subnet.private2.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_db_subnet_group" "rds_subnetgroup" {
  name = "rds_subnetgroup"
  subnet_ids = ["${aws_subnet.rds1.id}", "${aws_subnet.rds2.id}", "${aws_subnet.rds3.id}"]

  tags {
    Name = "rds_sng"
  }
}


#Create a Security Group with Ingress and Egress Rules and attach it to the VPC.

resource "aws_security_group" "public" {
  name = "sg_public"
  description = "Used for public and private instances for load balancer access"
  vpc_id = "${aws_vpc.vpc.id}"

  
 #SSH access from anywhere. Incoming from Port 22. 

  ingress {
    from_port   = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

    #HTTP access from the VPC

  ingress {
    from_port   = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # outbound internet access. -1 is for all protocols.

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Private Security Group

resource "aws_security_group" "private" {
  name        = "sg_private"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.vpc.id}"
  

  # Access from other security groups

  ingress {
    from_port    = 0
    to_port      = 0
    protocol     = "-1"
    cidr_blocks  = ["10.1.0.0/16"]
  }

  egress {
    from_port    = 0
    to_port      = 0
    protocol     = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

#Create a Security group for RDS instance.

resource "aws_security_group" "RDS" {
  name= "sg_rds"
  description = "Used for DB instances"
  vpc_id      = "${aws_vpc.vpc.id}"

  # SQL access from public/private security group

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.public.id}", "${aws_security_group.private.id}"]
  }
}

#Create a RDS Instance of engine type MySQL and predefined Database Credentials.
resource "aws_db_instance" "db" {
  allocated_storage = 10
  engine    = "mysql"
  engine_version  = "5.6.27"
  instance_class  = "${var.db_instance_class}"
  name      = "${var.dbname}"
  username    = "${var.dbuser}"
  password    = "${var.dbpassword}"
  db_subnet_group_name  = "${aws_db_subnet_group.rds_subnetgroup.name}"
  skip_final_snapshot   = "${var.skip_final_snapshot}"
  vpc_security_group_ids = ["${aws_security_group.RDS.id}"]
}


# AWS Key pair  to SSH into EC2 instances.

resource "aws_key_pair" "auth" {
  key_name  ="${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Create a EC2 instance of type Linux and run the Ansible script called Wordpress.yml to
# download and install WordPress on it using Remote Provisioner.

resource "aws_instance" "dev" {
  instance_type = "${var.dev_instance_type}"
  ami = "${var.dev_ami}"
  tags {
    Name = "wordpress-instance"
  }

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.public.id}"]
  subnet_id = "${aws_subnet.public.id}"


  provisioner "local-exec" {
      command = <<EOD
cat <<EOF > aws_hosts 
[dev] 
${aws_instance.dev.public_ip} 
EOF
EOD
  }

  provisioner "local-exec" {
    command = "sleep 6m && ansible-playbook -i aws_hosts wordpress.yml"
  }
}



