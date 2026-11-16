variable "environment" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "organization_id" {
  type        = string
  description = "Organisation ID (o-xxxxxxxxxx). Only accounts in it may link to the sink."
}

variable "resource_types" {
  type        = list(string)
  default     = ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup"]
  description = "Telemetry that source accounts may share. Add AWS::XRay::Trace for traces (billed)."

  validation {
    condition     = alltrue([for t in var.resource_types : contains(["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"], t)])
    error_message = "resource_types may only contain AWS::CloudWatch::Metric, AWS::Logs::LogGroup and AWS::XRay::Trace."
  }
}
