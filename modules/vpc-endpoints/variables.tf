variable "organization_name" {
  description = "Organisation short name, used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC (from modules/networking in this same repo) the endpoints are created in."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of that VPC. The shared endpoint security group allows HTTPS (443) from this range only."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "additional_ingress_cidr_blocks" {
  description = "Extra CIDR blocks allowed to reach the endpoints on TCP 443, for example the af-south-1 VPC CIDR when this module serves services that af-south-1 does not offer (cross-Region peering or Transit Gateway must exist). Empty by default."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.additional_ingress_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "additional_ingress_cidr_blocks must contain valid CIDR blocks."
  }
}

variable "subnet_ids" {
  description = "Private subnet IDs, one per Availability Zone, that receive the endpoint network interfaces. Never pass public subnets."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Pass at least two private subnets in different Availability Zones so every endpoint is Multi-AZ."
  }
}

variable "availability_zones" {
  description = "Availability Zone names of the subnets above (modules/networking output `azs`). Used to fail at plan time if a service is not offered in one of them."
  type        = list(string)
}

variable "interface_endpoints" {
  description = <<-EOT
    Interface endpoints (PrivateLink) to create, by AWS service short name. Approved catalogue:
      Tier 1 (first):  sqs, sns, secretsmanager, logs, events
      Tier 2 (later):  kms, monitoring, xray, ecr.api, ecr.dkr, sts
    Adding a service outside the catalogue is a deliberate code change (locals.tf, the validation list below and the README).
    Every endpoint is billed per hour per AZ plus per GB processed.
  EOT
  type        = list(string)
  default = [
    "sqs",
    "sns",
    "secretsmanager",
    "logs",
    "events",
    "kms",
    "monitoring",
    "xray",
    "ecr.api",
    "ecr.dkr",
    "sts",
  ]

  validation {
    condition = alltrue([
      for s in var.interface_endpoints : contains([
        "sqs", "sns", "secretsmanager", "logs", "events",
        "kms", "monitoring", "xray", "ecr.api", "ecr.dkr", "sts",
      ], s)
    ])
    error_message = "interface_endpoints may only contain: sqs, sns, secretsmanager, logs, events, kms, monitoring, xray, ecr.api, ecr.dkr, sts."
  }
}

variable "endpoint_policy_organization_id" {
  description = "AWS Organizations ID (o-xxxxxxxxxx). When set, every endpoint except sts gets an endpoint policy that only allows principals from this organisation (data perimeter). null keeps the default full-access endpoint policy. sts is excluded because AssumeRoleWithWebIdentity (for example EKS IRSA) is unauthenticated and carries no aws:PrincipalOrgID."
  type        = string
  default     = null

  validation {
    condition     = var.endpoint_policy_organization_id == null || can(regex("^o-[a-z0-9]{10,32}$", coalesce(var.endpoint_policy_organization_id, "x")))
    error_message = "endpoint_policy_organization_id must be null or look like o-xxxxxxxxxx."
  }
}

variable "tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
