variable "instance_type" {
  type        = string
  description = "EC2 Instance type for ASG workers"
  default     = "t3a.small"
}

variable "k3s_version" {
  type        = string
  description = "K3s version to install"
  default     = "v1.27.3+k3s1"
}

variable "k3s_token" {
  type        = string
  description = "K3s cluster token"
  sensitive   = true
}
