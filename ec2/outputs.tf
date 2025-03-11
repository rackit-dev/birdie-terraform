output "ec2_fastapi_id" {
  description = "The ID of the FastAPI EC2 instance"
  value       = module.ec2_instance_fastapi.id
}