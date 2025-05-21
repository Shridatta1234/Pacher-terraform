provider "aws" {
  region = "us-east-1"
}

# Get the latest AMI built by Packer
data "aws_ami" "my-pta-ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["my-pta-ami-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Reference existing security group
data "aws_security_group" "web_sg" {
  name = "web-sg"
}

# Update the existing launch template with new AMI
resource "aws_launch_template" "ubuntu_lt" {
  name_prefix   = "ubuntu-lt-"
  image_id      = data.aws_ami.my-pta-ami.id
  instance_type = "t3.micro"
  key_name      = "packer-key"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [data.aws_security_group.web_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Data source to reference existing ASG
data "aws_autoscaling_group" "existing_asg" {
  name = "ubuntu-packer-asg"
}

# Force ASG update by changing a tag (compatible with all AWS provider versions)
resource "null_resource" "trigger_asg_refresh" {
  triggers = {
    # Change this value to force refresh
    launch_template_version = aws_launch_template.ubuntu_lt.latest_version
  }

  provisioner "local-exec" {
    command = <<EOT
      aws autoscaling start-instance-refresh \
        --auto-scaling-group-name ${data.aws_autoscaling_group.existing_asg.name} \
        --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 300}' \
        --strategy Rolling
    EOT
  }

  depends_on = [aws_launch_template.ubuntu_lt]
}

# Outputs
output "new_ami_id" {
  value = data.aws_ami.my-pta-ami.id
}

output "launch_template_version" {
  value = aws_launch_template.ubuntu_lt.latest_version
}

output "refresh_triggered" {
  value = "ASG instance refresh initiated via AWS CLI"
}
