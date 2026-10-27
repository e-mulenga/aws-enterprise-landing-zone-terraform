terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"

      # aws.dr = disaster recovery region (eu-west-1) for cross-region copies.
      configuration_aliases = [aws.dr]
    }
  }
}
