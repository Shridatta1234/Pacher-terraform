resource "aws_instance" "packer-instance" {
  ami                    = var.ami_id != null ? var.ami_id : data.aws_ami.my_pta_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "WebServer"
  }
}
