provider "aws" {
  region = "${var.aws_region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

# Terraform  VPC
resource "aws_vpc" "terraform" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    enable_classiclink = "false"

}

# Terraform  Subnets
resource "aws_subnet" "terraform-public-1" {
    vpc_id = "${aws_vpc.terraform.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "${var.availability_zone}"
}

# Terraform  GW
resource "aws_internet_gateway" "terraform-gw" {
    vpc_id = "${aws_vpc.terraform.id}"

}

# Terraform  RTA
resource "aws_route_table_association" "terraform-public-1-a" {
    subnet_id = "${aws_subnet.terraform-public-1.id}"
    route_table_id = "${aws_route_table.terraform-public.id}"
}

# Terraform  RT
resource "aws_route_table" "terraform-public" {
    vpc_id = "${aws_vpc.terraform.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.terraform-gw.id}"
    }
}

resource "aws_security_group" "group" {
    vpc_id = "${aws_vpc.terraform.id}"
}

resource "aws_security_group_rule" "ingress_default" {
    from_port = 0
    to_port = 65535
    protocol = "-1"
    security_group_id = "${aws_security_group.group.id}"
    type = "ingress"
    cidr_blocks     = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress" {
    from_port = 0
    protocol = "-1"
    security_group_id = "${aws_security_group.group.id}"
    to_port = 65535
    type = "egress"
    cidr_blocks     = ["0.0.0.0/0"]
}
# AWS redis
resource "aws_elasticache_subnet_group" "default" {
  name       = "${var.namespace}-cache-subnet"
  subnet_ids = ["${aws_subnet.default.*.id}"]
}

resource "aws_elasticache_replication_group" "default" {
  replication_group_id          = "${var.cluster_id}"
  replication_group_description = "Redis cluster for Hashicorp ElastiCache example"

  node_type            = "cache.m4.large"
  port                 = 6379
  parameter_group_name = "default.redis3.2.cluster.on"

  snapshot_retention_limit = 5
  snapshot_window          = "00:00-05:00"

  subnet_group_name          = "${aws_elasticache_subnet_group.default.name}"
  automatic_failover_enabled = true

  cluster_mode {
    replicas_per_node_group = 1
    num_node_groups         = "${var.node_groups}"
  }
}


resource "aws_subnet" "terraform-private-1" {
    vpc_id = "${aws_vpc.terraform.id}"
    cidr_block = "10.0.3.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "${var.availability_zone}"
}


# Terraform  NG
resource "aws_eip" "terraform-nat" {
vpc = true
}

resource "aws_nat_gateway" "terraform-nat-gw" {
allocation_id = "${aws_eip.terraform-nat.id}"
subnet_id = "${aws_subnet.terraform-public-1.id}"
depends_on = ["aws_internet_gateway.terraform-gw"]
}

# Terraform VPC for NAT
resource "aws_route_table" "terraform-private" {
    vpc_id = "${aws_vpc.terraform.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.terraform-nat-gw.id}"
    }
    tags = {
      Name = "main"
    }
}

# Terraform private routes
resource "aws_route_table_association" "terraform-private-1-a" {
    subnet_id = "${aws_subnet.terraform-private-1.id}"
    route_table_id = "${aws_route_table.terraform-private.id}"
}

# Network LB
resource "aws_lb" "terraform-lb" {
  name               = "terraform-lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.terraform-public-1.id}"]
}

resource "aws_lb_target_group" "terraform_8000" {
  name     = "tf-terraform-lb-tg-first"
  port     = 8000
  protocol = "TCP"
  vpc_id   = "${aws_vpc.terraform.id}"
}

resource "aws_lb_target_group" "terraform_8001" {
  name     = "tf-terraform-lb-tg-second"
  port     = 8001
  protocol = "TCP"
  vpc_id   = "${aws_vpc.terraform.id}"
}

resource "aws_lb_target_group" "terraform_8002" {
  name     = "tf-terraform-lb-tg-third"
  port     = 8002
  protocol = "TCP"
  vpc_id   = "${aws_vpc.terraform.id}"
}


resource "aws_lb_listener" "terraform_8000" {
  load_balancer_arn = "${aws_lb.terraform-lb.arn}"
  port              = "8000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.terraform_8000.arn}"
  }
}
resource "aws_lb_listener" "terraform_8001" {
  load_balancer_arn = "${aws_lb.terraform-lb.arn}"
  port              = "8001"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.terraform_8001.arn}"
  }
}
resource "aws_lb_listener" "terraform_8002" {
  load_balancer_arn = "${aws_lb.terraform-lb.arn}"
  port              = "8002"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.terraform_8002.arn}"
  }
}

## Creating Launch Configuration
resource "aws_launch_configuration" "terraform-lc" {
  image_id               = "${var.aws_ami_id}"
  instance_type          = "t2.small"
  security_groups        = ["${aws_security_group.group.id}"]
  key_name               = "${var.aws_key_name}"
  root_block_device {
    delete_on_termination = true
  }

 user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y redis-tools
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terraform-asg" {
  name                 = "terraform"
  launch_configuration = "${aws_launch_configuration.terraform-lc.id}"
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier = ["${aws_subnet.terraform-private-1.id}"]
  target_group_arns = ["${aws_lb_target_group.terraform_8000.arn}", "${aws_lb_target_group.terraform_8001.arn}", "${aws_lb_target_group.terraform_8002.arn}"]

  lifecycle {
    create_before_destroy = true
  }
}

# scale up alarm
resource "aws_autoscaling_policy" "cpu-policy-scaleup" {
  name = "cpu-policy"
  autoscaling_group_name = "${aws_autoscaling_group.terraform-asg.name}"
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "1"
  cooldown = "300"
  policy_type = "SimpleScaling"
}
resource "aws_cloudwatch_metric_alarm" "cpu-alarm-scaleup" {
  alarm_name = "cpu-alarm-scaleup"
  alarm_description = "cpu-alarm-scaleup"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "80"
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.terraform-asg.name}"
  }
  actions_enabled = true
  alarm_actions = ["${aws_autoscaling_policy.cpu-policy-scaleup.arn}"]
}

# scale down alarm
resource "aws_autoscaling_policy" "cpu-policy-scaledown" {
  name = "example-cpu-policy-scaledown"
  autoscaling_group_name = "${aws_autoscaling_group.terraform-asg.name}"
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "-1"
  cooldown = "300"
  policy_type = "SimpleScaling"
  }

resource "aws_cloudwatch_metric_alarm" "cpu-alarm-scaledown" {
  alarm_name = "cpu-alarm-scaledown"
  alarm_description = "cpu-alarm-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"
  dimensions = {
  "AutoScalingGroupName" = "${aws_autoscaling_group.terraform-asg.name}"
  }
  actions_enabled = true
  alarm_actions = ["${aws_autoscaling_policy.cpu-policy-scaledown.arn}"]
}
