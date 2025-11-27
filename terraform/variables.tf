variable "alert_email" {

	description = "email address to be used for compliance alerts"
	type = string

}

variable "region" {
	description  = "aws region to deploy from"
	type = string
	default = "us-east-1"
}

variable "account_id" {
	description  = "aws account id number"
	type  = string
}