# AWS Terraform and Docker

**Terraform version:** v0.12.2
**Terraform AWS provider version:** v2.16.0

## Terraform

### Prerequisites
1) User should be created with next permissions:
  - AmazonEC2FullAccess
  - AutoScalingFullAccess
  - ElasticLoadBalancingFullAccess
  - AmazonVPCFullAccess
2) Choose community ami's with docker and centos (ami-04c0e22c2587597a4)
2) Access key should be generated for User and specified in terraform.tfvars file
3) .pem key should be created for EC2 instances access with SSH and update key name in terraform.tfvars. By default Usa-Shipt.pem key is expected to be created
4) By default Terraform will create resources in us-west. In order to change region AWS region, AZ, .pem key path terraform.tfvars file shoudl be updated



### Create AWS resources with Terraform and start docker containers
$ terraform init
$ terraform apply -var-file terraform.tfvars -auto-approve

### Remove AWS resources with Terraform
$ terraform destroy
