terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"

      # aws.us_east_1: ACM certificates used by CloudFront must live in us-east-1.
      configuration_aliases = [aws.us_east_1]
    }
  }
}
