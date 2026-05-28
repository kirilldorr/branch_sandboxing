#!/bin/bash
set -e

ACTION="install"
REGION=""

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

if [[ "$ACTION" == "install" ]]; then
    echo "=== 1. Provisioning ASG via Terraform ==="
    cd terraform
    terraform init
    
    echo -n "Enter K3s Token (required for worker nodes): "
    read -s K3S_TOKEN
    echo ""
    
    if [[ -z "$K3S_TOKEN" ]]; then
        echo "Error: K3s Token cannot be empty."
        exit 1
    fi
    
    terraform apply -var="k3s_token=$K3S_TOKEN"
    cd ..

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
    cd terraform
    terraform init
    terraform destroy -var="k3s_token=dummy_destroy_token"
    cd ..
    
    echo "✅ Uninstallation completed successfully!"
fi
