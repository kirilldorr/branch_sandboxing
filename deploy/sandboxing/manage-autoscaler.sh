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

echo "=== Fetching Kubeconfig and K3s Token from master node ==="

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

    echo "=== Fixing ProviderID on Master Node ==="

    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@"$BASE_IP" "bash -s" << 'EOF'
    CURRENT_PROVIDER=$(sudo k3s kubectl get node $(hostname) -o jsonpath='{.spec.providerID}' 2>/dev/null || echo "")
    
    if [[ "$CURRENT_PROVIDER" != aws://* ]]; then
        echo "🔧 Fixing K3s ProviderID to match AWS format..."
        TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
        INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
        AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
        
        sudo mkdir -p /etc/rancher/k3s/config.yaml.d
        sudo tee /etc/rancher/k3s/config.yaml.d/aws-provider.yaml > /dev/null <<INLINE_EOF
kubelet-arg:
  - "provider-id=aws:///${AZ}/${INSTANCE_ID}"
INLINE_EOF
        
        echo "Restarting K3s service to apply AWS Provider ID..."
        sudo k3s kubectl delete node $(hostname)
        sudo systemctl restart k3s
        sleep 15
    else
        echo "✅ Master node already has the correct AWS ProviderID."
    fi

    if [ ! -f /usr/local/bin/k3s-node-sweeper.sh ]; then
        echo "🧹 Creating daily NotReady node sweeper script..."
        sudo tee /usr/local/bin/k3s-node-sweeper.sh > /dev/null << 'INNER_EOF'
#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
/usr/local/bin/kubectl get nodes | grep NotReady | awk '{print $1}' | xargs -r /usr/local/bin/kubectl delete node
INNER_EOF
        
        sudo chmod +x /usr/local/bin/k3s-node-sweeper.sh
        
        echo "0 0 * * * root /usr/local/bin/k3s-node-sweeper.sh >> /var/log/k3s-node-sweeper.log 2>&1" | sudo tee /etc/cron.d/k3s-node-sweeper > /dev/null
        echo "✅ Daily cron job registered successfully (runs at 00:00)."
    else
        echo "✅ Node sweeper cron job already configured."
    fi
EOF

    echo "=== 1. Provisioning ASG via Terraform ==="
    cd "$SCRIPT_DIR/terraform"
    terraform init
    
    terraform apply -var="k3s_token=$K3S_TOKEN" -auto-approve
    
    echo "=== 2. Installing Cluster Autoscaler via Helm ==="
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    helm repo update

    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
      --namespace kube-system \
      --version 9.33.0 \
      --set image.tag=v1.27.3 \
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
    
    echo "=== 3. Cleaning up Master Node ==="
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@"$BASE_IP" "sudo rm -f /etc/cron.d/k3s-node-sweeper /usr/local/bin/k3s-node-sweeper.sh" || true
    echo "✅ Cron job cleaned up from Master node."

    echo "✅ Uninstallation completed successfully!"
fi