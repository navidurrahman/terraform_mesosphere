variable "exhibitor_s3_bucket_name" {}
variable "s3_docker_path" {}

resource "aws_s3_bucket" "Dcosexhibitors3bucket" {
    bucket = "${var.exhibitor_s3_bucket_name}"
    acl    = "private"
}

resource "aws_iam_user" "DcosIAMUser" {
    name = "DcosIAMUser"
    path = "/"
}

resource "aws_iam_user_policy" "DcosIAMUser_role" {
    name = "root"
    user = "${aws_iam_user.DcosIAMUser.name}"
    policy = <<POLICY
{
  "Statement": [
    {
      "Resource": [
        "arn:aws:s3:::${var.exhibitor_s3_bucket_name}/*",
        "arn:aws:s3:::${var.exhibitor_s3_bucket_name}"
      ],
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Effect": "Allow"
    },
    {
      "Resource": "*",
      "Action": [
        "ec2:DescribeKeyPairs",
        "ec2:DescribeSubnets",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeScalingActivities",
        "elasticloadbalancing:DescribeLoadBalancers"
      ],
      "Effect": "Allow"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_role" "DcosMasterRole" {
    name               = "DcosMasterRole"
    path               = "/"
    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "root" {
    name   = "root"
    role   = "${aws_iam_role.DcosMasterRole.id}"
    policy = <<POLICY
{
  "Statement": [
    {
      "Resource": [
        "arn:aws:s3:::${var.exhibitor_s3_bucket_name}/*",
        "arn:aws:s3:::${var.exhibitor_s3_bucket_name}",
        "arn:aws:s3:::${var.s3_docker_path}",
        "arn:aws:s3:::${var.s3_docker_path}/*"
      ],
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Effect": "Allow"
    },
    {
      "Resource": "*",
      "Action": [
        "ec2:DescribeKeyPairs",
        "ec2:DescribeSubnets",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeScalingActivities",
        "elasticloadbalancing:DescribeLoadBalancers"
      ],
      "Effect": "Allow"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}


resource "aws_iam_instance_profile" "DcosMasterInstanceProfile" {
    name  = "DcosMasterInstanceProfile"
    path  = "/"
    roles = ["${aws_iam_role.DcosMasterRole.id}"]
}


resource "aws_iam_role" "DcosSlaveRole" {
    name               = "DcosSlaveRole"
    path               = "/"
    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "slaves" {
    name   = "Slaves"
    role   = "${aws_iam_role.DcosSlaveRole.id}"
    policy = <<POLICY
{
  "Statement": [
    {
      "Resource": [
        "arn:aws:s3:::${var.exhibitor_s3_bucket_name}/*",
        "arn:aws:s3:::${var.exhibitor_s3_bucket_name}",
        "arn:aws:s3:::${var.s3_docker_path}",
        "arn:aws:s3:::${var.s3_docker_path}/*"
      ],
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Effect": "Allow"
    }
  ],
  "Version": "2012-10-17"
}
POLICY
}

resource "aws_iam_instance_profile" "DcosSlaveInstanceProfile" {
    name  = "DcosSlaveInstanceProfile"
    path  = "/"
    roles = ["${aws_iam_role.DcosSlaveRole.id}"]
}


resource "aws_iam_access_key" "DcosIAMUserKeys" {
    user = "${aws_iam_user.DcosIAMUser.name}"
}
