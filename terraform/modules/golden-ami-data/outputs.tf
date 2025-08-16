output "ami_id" {
  description = "ID of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.id
}

output "ami_name" {
  description = "Name of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.name
}

output "ami_description" {
  description = "Description of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.description
}

output "ami_owner_id" {
  description = "Owner ID of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.owner_id
}

output "ami_creation_date" {
  description = "Creation date of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.creation_date
}

output "ami_architecture" {
  description = "Architecture of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.architecture
}

output "ami_virtualization_type" {
  description = "Virtualization type of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.virtualization_type
}

output "ami_root_device_type" {
  description = "Root device type of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.root_device_type
}

output "ami_tags" {
  description = "Tags associated with the latest Golden AMI"
  value       = data.aws_ami.golden_ami.tags
}

output "ami_block_device_mappings" {
  description = "Block device mappings of the latest Golden AMI"
  value       = data.aws_ami.golden_ami.block_device_mappings
}
