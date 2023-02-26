variable "enable_autoscaling" {

  type = bool
  default = true
}

variable "give_neo_full_access" {
  type = bool
  description = "If true, give neo full access to Cloudwatch"
  default = false
}

variable "users" {
  type = list(string)
  default = ["neo", "morpheus","trinity"]
}