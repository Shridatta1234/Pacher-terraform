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

# Trigger ASG refresh using Terraform's AWS provider (no CLI dependency)
resource "aws_autoscaling_group" "asg_refresh" {
  # This creates a no-op update to force refresh
  name                = data.aws_autoscaling_group.existing_asg.name
  max_size            = data.aws_autoscaling_group.existing_asg.max_size
  min_size            = data.aws_autoscaling_group.existing_asg.min_size
  desired_capacity    = data.aws_autoscaling_group.existing_asg.desired_capacity
  vpc_zone_identifier = data.aws_autoscaling_group.existing_asg.vpc_zone_identifier

  launch_template {
    id      = aws_launch_template.ubuntu_lt.id
    version = "$Latest"
  }

  # Copy all other necessary attributes from the existing ASG
  health_check_type         = data.aws_autoscaling_group.existing_asg.health_check_type
  health_check_grace_period = data.aws_autoscaling_group.existing_asg.health_check_grace_period

  dynamic "tag" {
    for_each = data.aws_autoscaling_group.existing_asg.tags
    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to these attributes to prevent recreation
      load_balancers,
      target_group_arns,
      suspended_processes,
      enabled_metrics,
      termination_policies
    ]
  }
}

# Outputs
output "new_ami_id" {
  value = data.aws_ami.my-pta-ami.id
}

output "asg_refresh_triggered" {
  value = "ASG refresh triggered via launch template update"
}
