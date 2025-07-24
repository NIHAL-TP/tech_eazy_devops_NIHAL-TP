output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "config_bucket_name" {
  description = "The name of the S3 config bucket"
  value       = aws_s3_bucket.config_bucket.bucket
}
