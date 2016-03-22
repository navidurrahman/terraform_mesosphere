variable "cluster_name" {}
variable "region" {}
variable "private_subnets" {}
variable "public_subnets" {}
variable "key_name" {}

variable "master_instance_type" {default = "m3.xlarge"}
variable "master_min_instances" {default = "3"}
variable "master_max_instances" {default = "6"}

variable "slave_instance_type" {default = "m3.xlarge"}
variable "slave_min_instances" {default = "3"}
variable "slave_max_instances" {default = "10"}

variable "public_slave_instance_type" {default = "m3.xlarge"}
variable "public_slave_min_instances" {default = "1"}
variable "public_slave_max_instances" {default = "3"}

#stable 1.6
variable "bootstrap_id" {default = "18d094b1648521b017622180e3a8e05788a81e80"}
variable "download_url" {
    default = "https://downloads.mesosphere.com/dcos/stable/bootstrap/18d094b1648521b017622180e3a8e05788a81e80.bootstrap.tar.xz"
}

variable "coreos_ami" {
  description           = "CoreOS AMI to launch the instances"
  default = {
    eu-west-1           = "ami-55d20b26"
    us-west-2           = "ami-00ebfc61"
    sa-east-1           = "ami-154af179"
    us-east-1           = "ami-37bdc15d"
    ap-southeast-2      = "ami-f35b0590"
    ap-southeast-1      = "ami-da67a0b9"
    ap-northeast-1      = "ami-84e0c7ea"
    us-gov-west-1       = "ami-05bc0164"
    us-west-1           = "ami-27553a47"
    eu-central-1        = "ami-fdd4c791"
  }
}

resource "aws_elb" "DcosInternalMasterLoadBalancer" {
    name                        = "DcosInternalMasterLoadBalancer"
    subnets                     = ["${split(",", var.private_subnets)}"]
    security_groups             = [
        "${aws_security_group.DcosLbSecurityGroup.id}", 
        "${aws_security_group.DcosAdminSecurityGroup.id}",
        "${aws_security_group.DcosSlaveSecurityGroup.id}",
        "${aws_security_group.DcosPublicSlaveSecurityGroup.id}",
        "${aws_security_group.DcosMasterSecurityGroup.id}"
    ]
    internal                    = true
    cross_zone_load_balancing   = false
    idle_timeout                = 60
    connection_draining         = false
    connection_draining_timeout = 300

    listener {
        instance_port      = 8181
        instance_protocol  = "http"
        lb_port            = 8181
        lb_protocol        = "http"
    }

    listener {
        instance_port      = 2181
        instance_protocol  = "tcp"
        lb_port            = 2181
        lb_protocol        = "tcp"
    }

    listener {
        instance_port      = 443
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "tcp"
    }

    listener {
        instance_port      = 80
        instance_protocol  = "http"
        lb_port            = 80
        lb_protocol        = "http"
    }

    listener {
        instance_port      = 8080
        instance_protocol  = "http"
        lb_port            = 8080
        lb_protocol        = "http"
    }

    listener {
        instance_port      = 5050
        instance_protocol  = "http"
        lb_port            = 5050
        lb_protocol        = "http"
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 30
        target              = "HTTP:5050/health"
        timeout             = 5
    }

    tags {
        Name = "DcosInternalMasterLoadBalancer"
    }
}


resource "aws_elb" "DcosElasticLoadBalancer" {
    name                        = "DcosElasticLoadBalancer"
    subnets                     = ["${split(",", var.public_subnets)}"]
    security_groups             = ["${aws_security_group.DcosLbSecurityGroup.id}", "${aws_security_group.DcosAdminSecurityGroup.id}"]
    cross_zone_load_balancing   = true
    idle_timeout                = 60
    connection_draining         = false
    connection_draining_timeout = 300

    listener {
        instance_port      = 443
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "tcp"
        ssl_certificate_id = ""
    }

    listener {
        instance_port      = 80
        instance_protocol  = "http"
        lb_port            = 80
        lb_protocol        = "http"
        ssl_certificate_id = ""
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 30
        target              = "HTTP:5050/health"
        timeout             = 5
    }

    tags {
        Name = "DcosElasticLoadBalancer"
    }
}

resource "aws_elb" "DcosPublicSlaveLoadBalancer" {
    name                        = "DcosPublicSlaveLoadBalancer"
    subnets                     = ["${split(",", var.public_subnets)}"]
    security_groups             = ["${aws_security_group.DcosPublicSlaveSecurityGroup.id}"]
    cross_zone_load_balancing   = false
    idle_timeout                = 60
    connection_draining         = false
    connection_draining_timeout = 300

    listener {
        instance_port      = 443
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "tcp"
    }

    listener {
        instance_port      = 80
        instance_protocol  = "http"
        lb_port            = 80
        lb_protocol        = "http"
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 30
        target              = "HTTP:9090/_haproxy_health_check"
        timeout             = 5
    }

    tags {
        Name = "DcosPublicSlaveLoadBalancer"
    }
}

resource "template_file" "user_data_master" {
    template                  = "${file("${path.module}/user_data.tpl")}"
    vars {
        AWS_REGION              = "${var.region}"
        AWS_ACCESS_KEY_ID       = "${aws_iam_access_key.DcosIAMUserKeys.id}"
        AWS_SECRET_ACCESS_KEY   = "${aws_iam_access_key.DcosIAMUserKeys.secret}"
        AWS_S3_BUCKET           = "${var.exhibitor_s3_bucket_name}"
        MESOS_CLUSTER           = "${var.cluster_name}"
        MasterRole              = "${aws_iam_role.DcosMasterRole.name}"
        SlaveRole               = "${aws_iam_role.DcosSlaveRole.name}"
        EXHIBITOR_ADDRESS       = "${aws_elb.DcosInternalMasterLoadBalancer.dns_name}"
        S3_DOCKER_PATH          = "${var.s3_docker_path}"
        SERVER_GROUP            = "DcosMasterServerGroup"
        BOOTSTRAP_ID            = "${var.bootstrap_id}"
        DOWNLOAD_URL            = "${var.download_url}"
        ROLES                   = "- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/master\n- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/aws_master\n- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/aws\n"
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_launch_configuration" "MasterLaunchConfig" {
    name_prefix             = "DcosMasterLaunchConfig"
    image_id                = "${lookup(var.coreos_ami, var.region)}"
    instance_type           = "${var.master_instance_type}"
    key_name                = "${var.key_name}"
    security_groups         = ["${aws_security_group.DcosAdminSecurityGroup.id}", "${aws_security_group.DcosMasterSecurityGroup.id}"]
    associate_public_ip_address = false
    user_data               = "${template_file.user_data_master.rendered}"
    iam_instance_profile    = "${aws_iam_instance_profile.DcosMasterInstanceProfile.id}"
    lifecycle {
        create_before_destroy = true
    }
    ephemeral_block_device {
        device_name         = "/dev/sdb"
        virtual_name        = "ephemeral0"
    }
}

resource "aws_autoscaling_group" "DcosMasterServerGroup" {
    name                      = "DcosMasterServerGroup"
    min_size                  = "${var.master_min_instances}"
    max_size                  = "${var.master_max_instances}"
    health_check_grace_period = 300
    health_check_type         = "EC2"
    desired_capacity          = "${var.master_min_instances}"
    force_delete              = true
    launch_configuration      = "${aws_launch_configuration.MasterLaunchConfig.name}"
    vpc_zone_identifier       = ["${split(",", var.private_subnets)}"]
    load_balancers            = ["${aws_elb.DcosElasticLoadBalancer.name}", "${aws_elb.DcosInternalMasterLoadBalancer.name}"]
    termination_policies      = ["OldestLaunchConfiguration"]

    tag {
        key                     = "Name"
        value                   = "DcosMesosMaster"
        propagate_at_launch     = true
    }
}

resource "aws_autoscaling_policy" "DcosMasterUpSlacePolicy" {
    name = "DcosMasterUpSlacePolicy"
    scaling_adjustment = 2
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.DcosMasterServerGroup.name}"
}

resource "aws_cloudwatch_metric_alarm" "DcosMasterUpScaleAlarm" {
    alarm_name = "DcosMasterUpScaleAlarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "65"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.DcosMasterServerGroup.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.DcosUpSlacePolicy.arn}"]
}

resource "aws_autoscaling_policy" "DcosMasterDownSlacePolicy" {
    name = "DcosMasterDownSlacePolicy"
    scaling_adjustment = "-1"
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.DcosMasterServerGroup.name}"
}

resource "aws_cloudwatch_metric_alarm" "DcosMasterDownScaleAlarm" {
    alarm_name = "DcosMasterDownScaleAlarm"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "20"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.DcosMasterServerGroup.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.DcosDownSlacePolicy.arn}"]
}

resource "template_file" "user_data_slave" {
    template                  = "${file("${path.module}/user_data.tpl")}"
    vars {
        AWS_REGION              = "${var.region}"
        AWS_ACCESS_KEY_ID       = "${aws_iam_access_key.DcosIAMUserKeys.id}"
        AWS_SECRET_ACCESS_KEY   = "${aws_iam_access_key.DcosIAMUserKeys.secret}"
        AWS_S3_BUCKET           = "${var.exhibitor_s3_bucket_name}"
        MESOS_CLUSTER           = "${var.cluster_name}"
        MasterRole              = "${aws_iam_role.DcosMasterRole.name}"
        SlaveRole               = "${aws_iam_role.DcosSlaveRole.name}"
        EXHIBITOR_ADDRESS       = "${aws_elb.DcosInternalMasterLoadBalancer.dns_name}"
        S3_DOCKER_PATH          = "${var.s3_docker_path}"
        SERVER_GROUP            = "DcosSlaveServerGroup"
        BOOTSTRAP_ID            = "${var.bootstrap_id}"
        DOWNLOAD_URL            = "${var.download_url}"
        ROLES                   = "- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/slave\n- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/aws\n"
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_launch_configuration" "SlaveLaunchConfig" {
    name_prefix             = "DcosSlaveLaunchConfig"
    image_id                = "${lookup(var.coreos_ami, var.region)}"
    instance_type           = "${var.slave_instance_type}"
    key_name                = "${var.key_name}"
    security_groups         = ["${aws_security_group.DcosSlaveSecurityGroup.id}"]
    associate_public_ip_address = false
    user_data               = "${template_file.user_data_slave.rendered}"
    iam_instance_profile    = "${aws_iam_instance_profile.DcosSlaveInstanceProfile.id}"
    lifecycle {
        create_before_destroy = true
    }
    ephemeral_block_device {
        device_name         = "/dev/sdb"
        virtual_name        = "ephemeral0"
    }
}

resource "aws_autoscaling_policy" "DcosUpSlacePolicy" {
    name = "DcosUpSlacePolicy"
    scaling_adjustment = 2
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.DcosSlaveServerGroup.name}"
}

resource "aws_cloudwatch_metric_alarm" "DcosSlaveUpScaleAlarm" {
    alarm_name = "DcosSlaveUpScaleAlarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "65"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.DcosSlaveServerGroup.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.DcosUpSlacePolicy.arn}"]
}

resource "aws_autoscaling_policy" "DcosDownSlacePolicy" {
    name = "DcosDownSlacePolicy"
    scaling_adjustment = "-1"
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.DcosSlaveServerGroup.name}"
}

resource "aws_cloudwatch_metric_alarm" "DcosSlaveDownScaleAlarm" {
    alarm_name = "DcosSlaveDownScaleAlarm"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "20"
    dimensions {
        AutoScalingGroupName = "${aws_autoscaling_group.DcosSlaveServerGroup.name}"
    }
    alarm_description = "This metric monitor ec2 cpu utilization"
    alarm_actions = ["${aws_autoscaling_policy.DcosDownSlacePolicy.arn}"]
}

resource "aws_autoscaling_group" "DcosSlaveServerGroup" {
    name                      = "DcosSlaveServerGroup"
    min_size                  = "${var.slave_min_instances}"
    max_size                  = "${var.slave_max_instances}"
    health_check_grace_period = 300
    health_check_type         = "EC2"
    desired_capacity          = "${var.slave_min_instances}"
    force_delete              = true
    launch_configuration      = "${aws_launch_configuration.SlaveLaunchConfig.name}"
    vpc_zone_identifier       = ["${split(",", var.private_subnets)}"]
    termination_policies      = ["OldestLaunchConfiguration"]

    tag {
        key                     = "Name"
        value                   = "DcosMesosSlave"
        propagate_at_launch     = true
    }
}

resource "template_file" "user_data_public_slave" {
    template                  = "${file("${path.module}/user_data.tpl")}"
    vars {
        AWS_REGION              = "${var.region}"
        AWS_ACCESS_KEY_ID       = "${aws_iam_access_key.DcosIAMUserKeys.id}"
        AWS_SECRET_ACCESS_KEY   = "${aws_iam_access_key.DcosIAMUserKeys.secret}"
        AWS_S3_BUCKET           = "${var.exhibitor_s3_bucket_name}"
        MESOS_CLUSTER           = "${var.cluster_name}"
        MasterRole              = "${aws_iam_role.DcosMasterRole.name}"
        SlaveRole               = "${aws_iam_role.DcosSlaveRole.name}"
        EXHIBITOR_ADDRESS       = "${aws_elb.DcosInternalMasterLoadBalancer.dns_name}"
        S3_DOCKER_PATH          = "${var.s3_docker_path}"
        SERVER_GROUP            = "DcosPublicSlaveServerGroup"
        BOOTSTRAP_ID            = "${var.bootstrap_id}"
        DOWNLOAD_URL            = "${var.download_url}"
        ROLES                   = "- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/slave_public\n- \"content\": \"\"\n  \"path\": |-\n    /etc/mesosphere/roles/aws\n"
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_launch_configuration" "PublicSlaveLaunchConfig" {
    name_prefix             = "DcosPublicSlaveLaunchConfig"
    image_id                = "${lookup(var.coreos_ami, var.region)}"
    instance_type           = "${var.public_slave_instance_type}"
    key_name                = "${var.key_name}"
    security_groups         = ["${aws_security_group.DcosPublicSlaveSecurityGroup.id}"]
    associate_public_ip_address = false
    user_data               = "${template_file.user_data_public_slave.rendered}"
    iam_instance_profile    = "${aws_iam_instance_profile.DcosSlaveInstanceProfile.id}"
    lifecycle {
        create_before_destroy = true
    }
    ephemeral_block_device {
        device_name         = "/dev/sdb"
        virtual_name        = "ephemeral0"
    }
}

resource "aws_autoscaling_group" "DcosPublicSlaveServerGroup" {
    name                      = "DcosPublicSlaveServerGroup"
    min_size                  = "${var.public_slave_min_instances}"
    max_size                  = "${var.public_slave_max_instances}"
    health_check_grace_period = 300
    health_check_type         = "EC2"
    desired_capacity          = "${var.public_slave_min_instances}"
    force_delete              = true
    launch_configuration      = "${aws_launch_configuration.PublicSlaveLaunchConfig.name}"
    vpc_zone_identifier       = ["${split(",", var.private_subnets)}"]
    load_balancers            = ["${aws_elb.DcosPublicSlaveLoadBalancer.name}"]
    termination_policies      = ["OldestLaunchConfiguration"]

    tag {
        key                     = "Name"
        value                   = "DcosMesosPublicSlave"
        propagate_at_launch     = true
    }
}
