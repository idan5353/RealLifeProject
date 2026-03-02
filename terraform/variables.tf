variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_username" {
  type      = string
  default   = "taskadmin"
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "taskplatform"
}
