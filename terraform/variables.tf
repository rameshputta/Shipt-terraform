variable "aws_access_key" {}
variable "aws_secret_key" {}

#variable "aws_key_path" {
#    type = "string"
#}
#variable "aws_key_name" {}

variable "aws_region" {
    description = "EC2 Region for the VPC"
    default = "us-west-2"
}

variable "aws_az_for_public_subnet" {}

variable "aws_ami_id" {}

variable "aws_key_name" {}

variable "availability_zone" {}

variable "aws_az_for_private_subnet" {}
