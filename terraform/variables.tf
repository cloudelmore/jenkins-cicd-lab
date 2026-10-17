variable "region" {
  description = "AWS region to launch in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Free tier eligible instance type (t2.micro or t3.micro depending on account)"
  type        = string
  default     = "t2.micro"
}
