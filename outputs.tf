output "DcosElasticLoadBalancer" {
  value = "${aws_elb.DcosElasticLoadBalancer.dns_name}"
}
