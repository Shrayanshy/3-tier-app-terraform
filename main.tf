provider "aws" {
  region = "eu-north-1" # Change this to your desired region
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Security group for Nginx instance"
  
  // Add necessary inbound and outbound rules here
}

resource "aws_instance" "nginx_instance" {
  ami           = "ami-040d60c831d02d41c" # Replace with a valid AMI ID
  instance_type = "t2.micro"     # Change as needed
  subnet_id     = aws_subnet.public_subnet.id
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx

              cat << EOC > /etc/nginx/conf.d/reverse-proxy.conf
              server {
                  listen 80;
                  server_name example.com;

                  location / {
                      proxy_pass http://${aws_instance.tomcat_instance.private_ip}:8080;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                  }
              }
              EOC

              service nginx start
              chkconfig nginx on
              EOF
  
  security_groups = [aws_security_group.nginx_sg.id]
}

resource "aws_security_group" "tomcat_sg" {
  name        = "tomcat-sg"
  description = "Security group for Tomcat instance"
  
  // Add necessary inbound and outbound rules here
}

resource "aws_instance" "tomcat_instance" {
  ami           = "ami-12345678" # Replace with a valid AMI ID
  instance_type = "t2.micro"     # Change as needed
  subnet_id     = aws_subnet.private_subnet.id
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java-1.8.0-openjdk
              yum install -y tomcat8-webapps tomcat8-admin-webapps

              wget -O /usr/share/tomcat8/webapps/student.war http://example.com/path/to/student.war

              service tomcat8 start
              chkconfig tomcat8 on
              EOF
  
  security_groups = [aws_security_group.tomcat_sg.id]
}

resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 20
  storage_type        = "gp2"
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = "db.t2.micro"
  name                = "mydb"
  username            = "admin"
  password            = var.db_password
  parameter_group_name = "default.mysql5.7"
  
  // Add subnet group for private subnet
  // Add security group for RDS instance
}

output "public_instance_ip" {
  value = aws_instance.nginx_instance.public_ip
}

output "private_instance_ip" {
  value = aws_instance.tomcat_instance.private_ip
}
