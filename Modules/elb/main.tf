resource "aws_elb" "web" {
  # name = "nginx-elb"
  # subnets         = ["${aws_subnet.subnet.*.id}"]
  # security_groups = ["${aws_security_group.elb-sg.id}"]
  # instances       = ["${aws_instance.nginx.*.id}"]

  # subnets         = "${var.vSubnets}"
  subnets         = "${split(",",var.vSubnets)}"
  security_groups = "${var.vSecurity_groups}"
  instances       = "${split(",", var.vInstances)}"


  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

}