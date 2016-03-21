variable "vpc_id" {}
variable "vpc_cidr" {}

resource "aws_security_group" "DcosAdminSecurityGroup" {
    name        = "DcosAdminSecurityGroup"
    description = "Enable admin access to servers"
    vpc_id      = "${var.vpc_id}"

    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["${var.vpc_cidr}"]
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags {
        Name = "DcosAdminSecurityGroup"
    }
}

resource "aws_security_group" "DcosMasterSecurityGroup" {
    name        = "DcosMasterSecurityGroup"
    description = "Mesos Masters"
    vpc_id      = "${var.vpc_id}"

    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        self            = true
    }

    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = ["${aws_security_group.DcosLbSecurityGroup.id}"]
        self            = false
    }

    ingress {
        from_port       = 8080
        to_port         = 8080
        protocol        = "tcp"
        security_groups = ["${aws_security_group.DcosLbSecurityGroup.id}"]
        self            = false
    }

    ingress {
        from_port       = 5050
        to_port         = 5050
        protocol        = "tcp"
        security_groups = ["${aws_security_group.DcosLbSecurityGroup.id}"]
        self            = false
    }

    ingress {
        from_port       = 2181
        to_port         = 2181
        protocol        = "tcp"
        security_groups = ["${aws_security_group.DcosLbSecurityGroup.id}"]
        self            = false
    }

    ingress {
        from_port       = 8181
        to_port         = 8181
        protocol        = "tcp"
        security_groups = ["${aws_security_group.DcosLbSecurityGroup.id}"]
        self            = false
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags {
        Name = "DcosMasterSecurityGroup"
    }
}

#sg-dd5f75b8
resource "aws_security_group" "DcosLbSecurityGroup" {
    name        = "DcosLbSecurityGroup"
    description = "Mesos Master LB"
    vpc_id      = "${var.vpc_id}"

    ingress {
        from_port       = 2181
        to_port         = 2181
        protocol        = "tcp"
        security_groups = ["${aws_security_group.DcosSlaveSecurityGroup.id}"]
        self            = false
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags {
        Name = "DcosLbSecurityGroup"
    }
}


resource "aws_security_group" "DcosSlaveSecurityGroup" {
    name        = "DcosSlaveSecurityGroup"
    description = "Mesos Slaves"
    vpc_id      = "${var.vpc_id}"

    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        self            = true
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags {
        Name = "DcosSlaveSecurityGroup"
    }
}

resource "aws_security_group_rule" "MasterToSlave" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    depends_on = ["aws_security_group.DcosMasterSecurityGroup", "aws_security_group.DcosSlaveSecurityGroup"]

    security_group_id = "${aws_security_group.DcosMasterSecurityGroup.id}"
    source_security_group_id = "${aws_security_group.DcosSlaveSecurityGroup.id}"
}

resource "aws_security_group_rule" "MasterToPublicSlave" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    depends_on = ["aws_security_group.DcosMasterSecurityGroup", "aws_security_group.DcosPublicSlaveSecurityGroup"]
    
    security_group_id = "${aws_security_group.DcosMasterSecurityGroup.id}"
    source_security_group_id = "${aws_security_group.DcosPublicSlaveSecurityGroup.id}"
}

resource "aws_security_group_rule" "SlavetoMaster" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    depends_on = ["aws_security_group.DcosMasterSecurityGroup", "aws_security_group.DcosSlaveSecurityGroup"]

    security_group_id = "${aws_security_group.DcosSlaveSecurityGroup.id}"
    source_security_group_id = "${aws_security_group.DcosMasterSecurityGroup.id}"
}

resource "aws_security_group_rule" "SlavetoPublicSlave" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    depends_on = ["aws_security_group.DcosSlaveSecurityGroup", "aws_security_group.DcosPublicSlaveSecurityGroup"]

    security_group_id = "${aws_security_group.DcosSlaveSecurityGroup.id}"
    source_security_group_id = "${aws_security_group.DcosPublicSlaveSecurityGroup.id}"
}

#sg-d25f75b7
resource "aws_security_group" "DcosPublicSlaveSecurityGroup" {
    name        = "DcosPublicSlaveSecurityGroup"
    description = "Mesos Slaves Public"
    vpc_id      = "${var.vpc_id}"

    ingress {
        from_port       = 0
        to_port         = 21
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        self            = true
    }

    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        security_groups = ["${aws_security_group.DcosMasterSecurityGroup.id}", "${aws_security_group.DcosSlaveSecurityGroup.id}"]
        self            = false
    }

    ingress {
        from_port       = 5052
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 23
        to_port         = 5050
        protocol        = "udp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 5052
        to_port         = 65535
        protocol        = "udp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 0
        to_port         = 21
        protocol        = "udp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 23
        to_port         = 5050
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }


    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags {
        Name = "DcosPublicSlaveSecurityGroup"
    }
}

