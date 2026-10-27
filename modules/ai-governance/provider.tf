terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # aws_bedrock_guardrail and aws_bedrock_guardrail_version need a recent 5.x.
      version = ">= 5.80, < 6.0"

      # aws.ai = the Region where Bedrock is used (not every Region offers Bedrock).
      configuration_aliases = [aws.ai]
    }
  }
}
