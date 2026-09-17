variable "organization_id" { 
  type = string 
}

variable "organization_root_id" {
  type    = string
  default = ""
}

variable "allowed_regions" { 
  type = list(string) 
}

variable "environment" {
  type = string 
}
