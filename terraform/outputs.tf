output "public_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "ssh_command" {
  description = "Command to connect from this folder"
  value       = "ssh -i .\\jenkins-key ubuntu@${aws_instance.jenkins.public_ip}"
}

output "jenkins_url" {
  description = "Jenkins web UI (after Step 4)"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}
