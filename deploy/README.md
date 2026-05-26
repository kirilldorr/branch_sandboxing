## Work with ECR 

Perform all actions in this section in the directory; .../myadmin

Firstly we need to create ECR repository

    ```bash
    aws ecr create-repository --repository-name myadmin --region us-west-2'
    ```
Next, push docker image to ECR

    ```bash
    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-west-2.amazonaws.com
    
    <account_id> is your real account ID


    docker build -t myapp:latest .

    docker tag myapp:latest <account_id>.dkr.ecr.us-west-2.amazonaws.com/myadmin:latest

    docker push <account_id>.dkr.ecr.us-west-2.amazonaws.com/myadmin:latest
    ```
## Install Terraform 

    ```bash
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    ```

## Install Helm

    ```bash
    curl https://baltocdn.com/helm/signing.asc | sudo tee /etc/apt/trusted.gpg.d/helm.asc
    sudo apt-get install apt-transport-https --yes
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get install helm
    ```

## Install ansible:

    ```bash
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install ansible -y

    ```
## Start service

Perform all actions in this section in the directory; .../myadmin/deploy/terraform

    ```bash
    terraform init

    terraform apply -auto-approve
    ```

## All done!









