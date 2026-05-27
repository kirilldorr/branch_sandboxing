variable "instance_type" {
  description = "EC2 instance type for the dynamic worker"
  type        = string
}

variable "branch_slug" {
  description = "Branch slug used for naming the worker instance"
  type        = string
}

variable "k3s_token" {
  description = "K3s cluster token to join the master node"
  type        = string
  sensitive   = true
}

variable "k3s_version" {
  description = "K3s cluster version to install"
  type        = string
}
