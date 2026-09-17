variable "environment" { 
  type = string 
}

variable "organization_name" { 
  type = string 
}

variable "enabled" {
  type    = bool
  default = true
}

variable "findings_bucket" { 
  type = string 
}

variable "kms_key_arn" { 
  type = string 
}
