# Lookup the latest AMI
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

# Create a new launch template with the new AMI
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

# Use null_resource to update the ASG's launch template via AWS CLI
resource "null_resource" "update_asg_launch_template" {
  provisioner "local-exec" {
    command = <<EOT
      bash -c 'aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name ${data.aws_autoscaling_group.existing_asg.name} \
        --launch-template "LaunchTemplateId=${aws_launch_template.packer_lt.id},Version=${aws_launch_template.packer_lt.latest_version}"'
    EOT
  }

  triggers = {
    launch_template_version = aws_launch_template.packer_lt.latest_version
  }
}

# Optional: Trigger instance refresh after launch template update
resource "null_resource" "refresh_asg" {
  provisioner "local-exec" {
    command = <<EOT
      bash -c 'aws autoscaling start-instance-refresh \
        --auto-scaling-group-name ${data.aws_autoscaling_group.existing_asg.name} \
        --strategy Rolling \
        --preferences "{\"MinHealthyPercentage\": 50, \"InstanceWarmup\": 300}"'
    EOT
  }

  triggers = {
    launch_template_updated = null_resource.update_asg_launch_template.id
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
  value = "ASG refreshed with new AMI via updated launch template"
}
