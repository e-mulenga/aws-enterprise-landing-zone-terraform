output "macie_account_id" {
  description = "ID of the Macie account resource."
  value       = aws_macie2_account.this.id
}
