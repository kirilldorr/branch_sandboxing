#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACTION="install"

# Check for --uninstall flag
if [[ "$1" == "--uninstall" ]]; then
    ACTION="uninstall"
fi

echo -n "Enter AWS Region (e.g. us-west-2): "
read REGION

if [[ -z "$REGION" ]]; then
    echo "Error: AWS Region cannot be empty."
    exit 1
fi

echo "=== 0. Fetching Kubeconfig and K3s Token from master node ==="
# Get Base IP from main terraform stack
BASE_IP=$(cd "$SCRIPT_DIR/../terraform" && terraform output -raw public_ip)
if [[ -z "$BASE_IP" ]]; then
    echo "Error: Cannot get public_ip from base terraform state. Make sure base infrastructure is applied."
    exit 1
fi

SSH_KEY="$SCRIPT_DIR/../.keys/id_rsa"
if [[ ! -f "$SSH_KEY" ]]; then
    echo "Error: SSH key not found at $SSH_KEY"
    exit 1
fi

chmod 600 "$SSH_KEY"
mkdir -p ~/.kube

ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@"$BASE_IP" "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
sed -i "s/127.0.0.1/$BASE_IP/g" ~/.kube/config
sed -i 's/certificate-authority-data:.*/insecure-skip-tls-verify: true/g' ~/.kube/config

echo "✅ Kubeconfig successfully updated for K3s cluster at $BASE_IP"

# Fetch K3s node token for the autoscaler workers
K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@"$BASE_IP" "sudo cat /var/lib/rancher/k3s/server/node-token")
if [[ -z "$K3S_TOKEN" ]]; then
    echo "Error: Failed to fetch K3s node token."
    exit 1
fi
echo "✅ K3s token successfully fetched."

if [[ "$ACTION" == "install" ]]; then
    echo "=== 1. Provisioning ASG via Terraform ==="
    cd "$SCRIPT_DIR/terraform"
    terraform init
    
    terraform apply -var="k3s_token=$K3S_TOKEN" -auto-approve
    
    echo "=== 2. Installing Cluster Autoscaler via Helm ==="
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    helm repo update

    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
      --namespace kube-system \
      --set autoDiscovery.clusterName=my-sandbox-cluster \
      --set autoDiscovery.tags[0]=k8s.io/cluster-autoscaler/enabled \
      --set autoDiscovery.tags[1]=k8s.io/cluster-autoscaler/my-sandbox-cluster \
      --set awsRegion="$REGION" \
      --set extraArgs.scale-down-delay-after-add=5m \
      --set extraArgs.scale-down-unneeded-time=5m \
      --set extraArgs.skip-nodes-with-system-pods=false \
      --set extraArgs.skip-nodes-with-local-storage=false

    echo "✅ Installation completed successfully!"

elif [[ "$ACTION" == "uninstall" ]]; then
    echo "=== 1. Uninstalling Cluster Autoscaler via Helm ==="
    helm uninstall cluster-autoscaler --namespace kube-system || echo "Autoscaler already uninstalled or not found."

    echo "=== 2. Destroying ASG via Terraform ==="
    cd "$SCRIPT_DIR/terraform"
    terraform init
    terraform destroy -var="k3s_token=$K3S_TOKEN" -auto-approve
    
    echo "✅ Uninstallation completed successfully!"
fi
