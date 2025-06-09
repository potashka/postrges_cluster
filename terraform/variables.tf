# terraform/variables.tf
variable "yc_cloud_id" {}
variable "yc_folder_id" {}
variable "yc_zone" {}
variable "service_account_key_file" {}
variable "instance_image" {}
variable "instance_user" {}
# variable "ssh_public_key_path" {}
variable "ssh_public_key" {
  description = "Public SSH key for accessing instances"
  type        = string
}