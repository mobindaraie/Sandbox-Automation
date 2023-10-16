
variable "sandbox-mg-id" {
  type    = string
  default = "Sandbox"
}

variable "decomissioned-mg-id" {
  type    = string
  default = "cancelled"
}


variable "location" {
  type    = string
}

variable "resource-prefix" {
  type    = string
  default = "sandbox-automation"
}

variable "runbook_uri" {
  type    = string
}