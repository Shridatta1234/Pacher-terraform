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
resource "aws_launch_template" "packer_lt" {
  name_prefix   = "packer-lt-"
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

# Reference the existing Auto Scaling Group
data "aws_autoscaling_group" "existing_asg" {
  name = "ubuntu-packer-asg"
}

# Update the existing Auto Scaling Group to use the new launch template
resource "aws_autoscaling_group" "packer_asg" {
  # Use the same name to update the existing ASG
  name = data.aws_autoscaling_group.existing_asg.name

  # Use the new launch template
  launch_template {
    id      = aws_launch_template.packer_lt.id
    version = "$Latest"
  }

  # Configure instance refresh preferences
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
      auto_rollback          = true
    }
  }

  # Preserve other settings that might be managed outside Terraform
  lifecycle {
    ignore_changes = [
      desired_capacity,
      load_balancers,
      target_group_arns,
      max_size,
      min_size,
      vpc_zone_identifier,
      health_check_type
    ]
  }
}

# Outputs
output "new_packer_ami_id" {
  value = data.aws_ami.my-pta-ami.id
}

output "launch_template_version" {
  value = aws_launch_template.packer_lt.latest_version
}

output "asg_refresh_status" {
  value = "ASG configured for rolling update with new AMI"
}
