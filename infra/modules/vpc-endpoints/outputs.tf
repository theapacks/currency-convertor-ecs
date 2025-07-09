output "vpc_endpoints" {
  description = "Map of VPC endpoint information"
  value = merge(
    {
      for name, endpoint in aws_vpc_endpoint.gateway : name => {
        id           = endpoint.id
        arn          = endpoint.arn
        type         = endpoint.vpc_endpoint_type
        service_name = endpoint.service_name
        state        = endpoint.state
      }
    },
    {
      for name, endpoint in aws_vpc_endpoint.interface : name => {
        id                    = endpoint.id
        arn                   = endpoint.arn
        type                  = endpoint.vpc_endpoint_type
        service_name          = endpoint.service_name
        state                 = endpoint.state
        dns_entries           = endpoint.dns_entry
        network_interface_ids = endpoint.network_interface_ids
      }
    }
  )
}

output "gateway_endpoints" {
  description = "Map of gateway VPC endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.gateway : name => {
      id           = endpoint.id
      arn          = endpoint.arn
      service_name = endpoint.service_name
      state        = endpoint.state
    }
  }
}

output "interface_endpoints" {
  description = "Map of interface VPC endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.interface : name => {
      id                    = endpoint.id
      arn                   = endpoint.arn
      service_name          = endpoint.service_name
      state                 = endpoint.state
      dns_entries           = endpoint.dns_entry
      network_interface_ids = endpoint.network_interface_ids
    }
  }
}

output "security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = length(aws_security_group.vpc_endpoints) > 0 ? aws_security_group.vpc_endpoints[0].id : null
}

output "endpoint_count" {
  description = "Total number of VPC endpoints created"
  value = {
    gateway   = length(aws_vpc_endpoint.gateway)
    interface = length(aws_vpc_endpoint.interface)
    total     = length(aws_vpc_endpoint.gateway) + length(aws_vpc_endpoint.interface)
  }
}

output "endpoints_config" {
  description = "Configuration of created endpoints"
  value = {
    gateway   = local.gateway_endpoints
    interface = local.interface_endpoints
  }
}