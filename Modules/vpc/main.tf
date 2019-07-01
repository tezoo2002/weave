resource "aws_vpc" "vpc" {
  cidr_block = "${var.network_address_space}"

  # tags {
  #   Name        = "${var.environment_tag}-vpc"
  #   BillingCode = "${var.billing_code_tag}"
  #   Environment = "${var.environment_tag}"
  # }
}