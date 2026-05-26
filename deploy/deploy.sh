#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting deployment process..."

echo "Running Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

REPO_URL=$(terraform output -raw ecr_repository_url)
ACCOUNT_ID=$(terraform output -raw account_id)
REGION=$(terraform output -raw aws_region)
TAG=$(terraform output -raw hash)
PUBLIC_IP=$(terraform output -raw public_ip)
APP_SOURCE_CODE_PATH="../"
cd ..

echo "Building and Pushing Docker Image..."
echo "LOG: Logging in to ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo "LOG: Building Docker image..."
unset DOCKER_HOST
docker build --pull -t ${REPO_URL}:${TAG} ${APP_SOURCE_CODE_PATH}

echo "LOG: Pushing image to ECR..."
docker push ${REPO_URL}:${TAG}
echo "LOG: Build and push complete. TAG=${TAG}"

echo "Waiting for SSH on ${PUBLIC_IP}..."
for i in {1..20}; do
  nc -zv ${PUBLIC_IP} 22 && echo "SSH is ready!" && break
  echo "Retrying in 5 seconds..."
  sleep 5
  if [ $i -eq 20 ]; then
    echo "SSH not ready after 100 seconds. Exiting."
    exit 1
  fi
done

echo "Running Ansible..."
cd ansible
ANSIBLE_HOST_KEY_CHECKING=False ansible-galaxy collection install community.kubernetes
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbooks/playbook.yaml
cd ..

echo "Fetching kubeconfig and deploying via Helmfile..."
ssh -o StrictHostKeyChecking=no -i .keys/id_rsa ubuntu@${PUBLIC_IP} "sudo cat /etc/rancher/k3s/k3s.yaml" > kubeconfig.yaml
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

cd helm
export APP_NAMESPACE="myadmin"
export IMAGE_FULL_TAG="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/myadmink3s:${TAG}"
helmfile apply
cd ..

echo "Deployment complete!"
echo ""

cd terraform
terraform output
