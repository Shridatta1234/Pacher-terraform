output "public_ip" {
  value = aws_instance.packer-instance.public_ip
}

output "instance_id" {
  value = aws_instance.packer-instance.id
}
