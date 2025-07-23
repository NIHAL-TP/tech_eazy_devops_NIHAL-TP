# tech_eazy_devops_NIHAL-TP
tech eazy pre intern 1st assignment
how to run:
1)create an aws access key and configure aws on your machine
2)generate an ssh key nad add private key location to key pair variable in terraform/variables.tf
3)run terraform init,plan and apply while specifying the environment config and tfvars files
4)Get public ip of the ec2 from output and ssh into the server using the appropriate username and key pair
5)userdata script is automatically ran and the repo is cloned and deployed