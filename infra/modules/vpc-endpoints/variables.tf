variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "region" {
  description = "AWS region where the VPC endpoints will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for interface endpoints"
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs for gateway endpoints"
  type        = list(string)
  default     = []
}

variable "endpoints" {
  description = "Map of VPC endpoints to create"
  type = map(object({
    service              = string
    type                 = string # "Gateway" or "Interface"
    private_dns_enabled  = optional(bool, true)
    policy               = optional(string, null)
  }))

  validation {
    condition = alltrue([
      for endpoint_name, endpoint_config in var.endpoints : 
      contains(["Gateway", "Interface"], endpoint_config.type)
    ])
    error_message = "The 'type' field must be either 'Gateway' or 'Interface'."
  }  
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "security_group_ingress_rules" {
  description = "Additional ingress rules for VPC endpoint security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable sg_egress_cidr_blocks {
  description = "CIDR blocks for egress rules in VPC endpoint security group"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}