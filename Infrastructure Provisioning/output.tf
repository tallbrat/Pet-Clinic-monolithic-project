/*
output "key_pair" {
  value = aws_key_pair.my_key_pair.key_name
}

output "public_Instance_ip" {
  value = "ssh -i ${ aws_key_pair.my_key_pair.key_name } ubuntu@${aws_instance.public_instance.public_ip}"
}

output "db_Instance_ip" {
  value = "ssh -i ${ aws_key_pair.my_key_pair.key_name } ubuntu@${aws_instance.private_db_instance.public_ip}"
}

output "tomcat_Instance_ip" {
  value = "ssh -i ${ aws_key_pair.my_key_pair.key_name } ubuntu@${aws_instance.private_tomcat_instance.public_ip}"
}

output "proxy_Instance_ip" {
  value = "ssh -i ${ aws_key_pair.my_key_pair.key_name } ubuntu@${aws_instance.private_proxy_instance.public_ip}"
}

output "ami_id" {
  value = data.aws_ami.ubuntu_os.id
}
*/