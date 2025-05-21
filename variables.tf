variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}



data "aws_ami" "my_pta_ami" {
  most_recent = true
  owners      = ["self"] # Or your AWS account ID

  filter {
    name   = "name"
    values = ["my-pta-ami-*"] # Match your Packer AMI naming pattern
  }
}

variable "ami_id" {
  description = "AMI ID Custom with packer"
  type        = string
  default     = null # Default to null to allow data source to be used
}
