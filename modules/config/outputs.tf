output "recorder_name"   { value = aws_config_configuration_recorder.main.name }
output "config_role_arn" { value = aws_iam_role.config.arn }
