locals {
  gateway_endpoints = {
    for name, config in var.endpoints : name => config
    if config.type == "Gateway"
  }

  interface_endpoints = {
    for name, config in var.endpoints : name => config
    if config.type == "Interface"
  }
}