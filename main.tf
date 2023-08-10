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

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-north-1b"
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "my-1rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 20
  storage_type        = "gp2"
  engine              = "mariadb"
  engine_version      = "10.4"
  instance_class      = "db.t3.micro"
  identifier          = "mydb1"
  username            = var.database_username
  password            = var.database_password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot = true

  tags = {
    Name = "MyRDSInstance"
  }

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  // Remove the provisioner "remote-exec" block

  lifecycle {
    ignore_changes = [allocated_storage, engine_version]
  }
}

  
resource "null_resource" "create_database" {
  triggers = {
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      /usr/bin/mysql -h ${aws_db_instance.rds_instance.endpoint} -u ${var.database_username} -p${var.database_password} -e 'CREATE DATABASE IF NOT EXISTS studentapp;'
      /usr/bin/mysql -h ${aws_db_instance.rds_instance.endpoint} -u ${var.database_username} -p${var.database_password} -D studentapp -e 'CREATE TABLE IF NOT EXISTS students (student_id INT NOT NULL AUTO_INCREMENT, student_name VARCHAR(100) NOT NULL, student_addr VARCHAR(100) NOT NULL, student_age VARCHAR(3) NOT NULL, student_qual VARCHAR(20) NOT NULL, student_percent VARCHAR(10) NOT NULL, student_year_passed VARCHAR(10) NOT NULL, PRIMARY KEY (student_id));'
    EOT
  }
}



resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS instance"
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Add more inbound rules as needed
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Security group for Nginx instance"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Add more inbound rules as needed
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tomcat_sg" {
  name        = "tomcat-sg"
  description = "Security group for Tomcat instance"
  
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_sg.id] # Allow traffic from Nginx instance
  }
  
  // Add more inbound rules as needed
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "tomcat_instance" {
  ami           = "ami-0cea4844b980fe49e" # Replace with a valid AMI ID
  instance_type = "t3.micro"     # Change as needed
  subnet_id     = aws_subnet.private_subnet_1.id
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java-1.8.0-amazon-corretto-devel.x86_64 
              wget https://dlcdn.apache.org/tomcat/tomcat-8/v8.5.91/bin/apache-tomcat-8.5.91.zip
              unzip apache-tomcat-8.5.91.zip
              mv apache-tomcat-8.5.91 apache
              cd apache
              cd webapps && wget https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war
              cd .. && cd lib  && wget https://s3-us-west-2.amazonaws.com/studentapi-cit/mysql-connector.jar
              cd .. && sudo chmod 744 bin/* && cd bin &&  bash startup.sh

              echo -e "<?xml version='1.0' encoding='utf-8'?>
<Context>
    <Resource name=\"jdbc/TestDB\" auth=\"Container\" type=\"javax.sql.DataSource\" 
              maxActive=\"100\" maxIdle=\"30\" maxWait=\"10000\" username=\"${var.database_username}\" password=\"${var.database_password}\" 
              driverClassName=\"com.mysql.jdbc.Driver\"
              url=\"jdbc:mysql://${aws_db_instance.rds_instance.endpoint}:3306/${var.database_name}?autoReconnect=true\" 
              validationQuery=\"SELECT 1\" testOnBorrow=\"true\" />
</Context>" > /root/apache/conf/context.xml
              EOF
  
  security_groups = [aws_security_group.tomcat_sg.id]
}

resource "aws_instance" "nginx_instance" {
  ami           = "ami-0cea4844b980fe49e" # Replace with a valid AMI ID
  instance_type = "t3.micro"     # Change as needed
  subnet_id     = aws_subnet.public_subnet.id
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx

              cat << EOC > /etc/nginx/conf.d/reverse-proxy.conf
              server {
                  listen 80;

                  location / {
                      proxy_pass http://${aws_instance.tomcat_instance.private_ip}:8080;
                  }
              }
              EOC

              service nginx start
              chkconfig nginx on
              EOF
  
  security_groups = [aws_security_group.nginx_sg.id]
}

variable "database_username" {
  description = "Database username"
}

variable "database_password" {
  description = "Database password"
}

variable "database_name" {
  description = "Database name"
}

output "public_instance_ip" {
  value = aws_instance.nginx_instance.public_ip
}

output "private_instance_ip" {
  value = aws_instance.tomcat_instance.private_ip
}

output "rds_endpoint" {
  value = aws_db_instance.rds_instance.endpoint
}
