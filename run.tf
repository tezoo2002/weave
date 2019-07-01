##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "key_name" {
  default = "TerraUser_Key"
}

variable "network_address_space" {
  default = "10.1.0.0/16"
}

variable "billing_code_tag" {}
variable "environment_tag" {}

variable "instance_count" {
}

variable "subnet_count" {
}


##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}



##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
module "vpc" {
  source = "./Modules/vpc"

  network_address_space = "${var.network_address_space}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${module.vpc.id}"

  # tags {
  #   Name        = "${var.environment_tag}-igw"
  #   BillingCode = "${var.billing_code_tag}"
  #   Environment = "${var.environment_tag}"
  # }
}

resource "aws_subnet" "subnet" {
  count                   = "${var.subnet_count}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 1)}"
  vpc_id                  = "${module.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  # tags {
  #   Name        = "${var.environment_tag}-subnet-${count.index + 1}"
  #   BillingCode = "${var.billing_code_tag}"
  #   Environment = "${var.environment_tag}"
  # }
}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = "${module.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  # tags {
  #   Name        = "${var.environment_tag}-rtb"
  #   BillingCode = "${var.billing_code_tag}"
  #   Environment = "${var.environment_tag}"
  # }
}

resource "aws_route_table_association" "rta-subnet" {
  count          = "${var.subnet_count}"
  subnet_id      = "${element(aws_subnet.subnet.*.id,count.index)}"
  route_table_id = "${aws_route_table.rtb.id}"
}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "nginx_elb_sg"
  vpc_id = "${module.vpc.id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # tags {
  #   Name        = "${var.environment_tag}-elb-sg"
  #   BillingCode = "${var.billing_code_tag}"
  #   Environment = "${var.environment_tag}"
  # }
}

# Nginx security group 
resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = "${module.vpc.id}"

  # SSH access from anywhere
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
    cidr_blocks = ["${var.network_address_space}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LOAD BALANCER #

module "elb"{
  source = "./Modules/elb"
  
  vSubnets         = "${join(",",aws_subnet.subnet.*.id)}"
  vSecurity_groups = ["${aws_security_group.elb-sg.id}"]
  vInstances       = "${join(",", aws_instance.nginx.*.id)}"
}



# resource "aws_elb" "web" {
#   name = "nginx-elb"

#   subnets         = ["${aws_subnet.subnet.*.id}"]
#   security_groups = ["${aws_security_group.elb-sg.id}"]
#   instances       = ["${aws_instance.nginx.*.id}"]

#   listener {
#     instance_port     = 80
#     instance_protocol = "http"
#     lb_port           = 80
#     lb_protocol       = "http"
#   }

#   tags {
#     Name        = "${var.environment_tag}-elb"
#     BillingCode = "${var.billing_code_tag}"
#     Environment = "${var.environment_tag}"
#   }
# }

# INSTANCES #
resource "aws_instance" "nginx" {
  count                  = "${var.instance_count}"
  ami                    = "ami-c58c1dd3"
  instance_type          = "t2.micro"
  subnet_id              = "${element(aws_subnet.subnet.*.id,count.index % var.subnet_count)}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
    host = "${self.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "echo '<html><head><title>Subnet ${count.index}</title></head><body><p style=\"text-align: center;\"><span><span>Subnet 1</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }

  # tags {
  #   Name        = "${var.environment_tag}-nginx-${count.index + 1}"
  #   BillingCode = "${var.billing_code_tag}"
  #   Environment = "${var.environment_tag}"
  # }
}


##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = "${module.elb.dns_name}"
}