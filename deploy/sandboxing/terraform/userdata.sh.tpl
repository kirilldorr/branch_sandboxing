#!/bin/bash
set -e
apt-get update
apt-get install -y awscli

echo '#!/bin/bash' > /usr/local/bin/update-ecr-token.sh
echo 'TOKEN=$(aws ecr get-login-password --region ${aws_region})' >> /usr/local/bin/update-ecr-token.sh
echo 'mkdir -p /etc/rancher/k3s' >> /usr/local/bin/update-ecr-token.sh
echo 'cat <<YAML > /etc/rancher/k3s/registries.yaml' >> /usr/local/bin/update-ecr-token.sh
echo 'configs:' >> /usr/local/bin/update-ecr-token.sh
echo '  "${account_id}.dkr.ecr.${aws_region}.amazonaws.com":' >> /usr/local/bin/update-ecr-token.sh
echo '    auth:' >> /usr/local/bin/update-ecr-token.sh
echo '      username: AWS' >> /usr/local/bin/update-ecr-token.sh
echo '      password: "$TOKEN"' >> /usr/local/bin/update-ecr-token.sh
echo 'YAML' >> /usr/local/bin/update-ecr-token.sh

echo 'systemctl restart k3s-agent || true' >> /usr/local/bin/update-ecr-token.sh
chmod +x /usr/local/bin/update-ecr-token.sh
/usr/local/bin/update-ecr-token.sh

echo "0 */10 * * * root /usr/local/bin/update-ecr-token.sh > /var/log/ecr-cron.log 2>&1" > /etc/cron.d/update-ecr-token

EC2_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" K3S_URL="https://${public_ip}:6443" K3S_TOKEN="${k3s_token}" sh -s - agent --kubelet-arg="provider-id=aws:///$AZ/$INSTANCE_ID"