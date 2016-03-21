# terraform_mesosphere
Terraform module for mesosphere 1.6.1


## How to Use:
Include this module with following parameters to start the new cluster inside the AWS VPC

```
provider "aws" {
  access_key  				= "${var.access_key}"
  secret_key  				= "${var.secret_key}"
  region      				= "${var.region}"
}

module "mesosphere" {
	source = "github.com/navidurrahman/terraform_mesosphere"

	cluster_name = "cluster-name"
	region = "${var.region}"
	vpc_cidr = "${var.cidr}"
	vpc_id = "<VPC_ID>"
	exhibitor_s3_bucket_name = "<S3_BUCKET_NAME_FOR_EXHIBITOR>"
	s3_docker_path = "<YOU_CAN_SPECIFY_DOCKERCFG_S3_PATH_TO_DOWNLOAD_ON_SLAVE>"
	private_subnets = "subnet-1,subnet-2,subnet-3"
	public_subnets = "subnet-2,subnet-2,subnet-3"
	key_name = "${var.key_name}"
	slave_instance_type = "m3.xlarge"
}
```

Right now, Admin location security group is not managed by Terraform. After completion of script, go to secutiry groups and whitelist your IP in AdminLocationSecutiryGroup.
