# VPC Endpoints Module - Usage Examples

This document provides examples of how to use the refactored VPC endpoints module with the new `endpoints` variable structure.

## 🚀 Basic Usage

### Minimal Configuration (ECS Fargate Essentials)

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  endpoints = {
    # Gateway endpoint (free)
    s3 = {
      service = "s3"
      type    = "Gateway"
    }

    # Interface endpoints (paid) - Essential for ECS
    ecr-api = {
      service = "ecr.api"
      type    = "Interface"
    }
    ecr-dkr = {
      service = "ecr.dkr"
      type    = "Interface"
    }
    logs = {
      service = "logs"
      type    = "Interface"
    }
  }

  tags = {
    Environment = "dev"
    Project     = "my-app"
  }
}
```

### Cost: ~$21.60/month for the above configuration

## 🔧 Advanced Usage

### Full ECS Fargate Configuration

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  endpoints = {
    # Gateway endpoints (free)
    s3 = {
      service = "s3"
      type    = "Gateway"
    }
    dynamodb = {
      service = "dynamodb"
      type    = "Gateway"
    }

    # Interface endpoints (paid)
    ecr-api = {
      service = "ecr.api"
      type    = "Interface"
    }
    ecr-dkr = {
      service = "ecr.dkr"
      type    = "Interface"
    }
    ecs = {
      service = "ecs"
      type    = "Interface"
    }
    ecs-agent = {
      service = "ecs-agent"
      type    = "Interface"
    }
    ecs-telemetry = {
      service = "ecs-telemetry"
      type    = "Interface"
    }
    logs = {
      service = "logs"
      type    = "Interface"
    }
    monitoring = {
      service = "monitoring"
      type    = "Interface"
    }
    ssm = {
      service = "ssm"
      type    = "Interface"
    }
    kms = {
      service = "kms"
      type    = "Interface"
    }
    secretsmanager = {
      service = "secretsmanager"
      type    = "Interface"
    }
  }

  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}
```

### Cost: ~$72/month for the above configuration

## 🔒 Usage with IAM Policies

### Restricting Access with IAM Policies

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  endpoints = {
    s3 = {
      service = "s3"
      type    = "Gateway"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "s3:GetObject",
              "s3:PutObject"
            ]
            Resource = [
              "arn:aws:s3:::my-bucket/*"
            ]
          }
        ]
      })
    }

    ecr-api = {
      service = "ecr.api"
      type    = "Interface"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                "aws:PrincipalTag/Environment" = "production"
              }
            }
          }
        ]
      })
    }
  }
}
```

## 🛡️ Custom Security Group Rules

### Adding Custom Security Group Rules

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  endpoints = {
    logs = {
      service = "logs"
      type    = "Interface"
    }
  }

  # Custom security group rules
  security_group_ingress_rules = [
    {
      description = "Custom application port"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Database port"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"]
    }
  ]

  tags = {
    Environment = "dev"
  }
}
```

## 📊 Environment-Specific Configurations

### Development Environment (Cost-Optimized)

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  endpoints = {
    # Only essential endpoints for development
    s3 = {
      service = "s3"
      type    = "Gateway"
    }
    ecr-api = {
      service = "ecr.api"
      type    = "Interface"
    }
    ecr-dkr = {
      service = "ecr.dkr"
      type    = "Interface"
    }
    logs = {
      service = "logs"
      type    = "Interface"
    }
  }

  tags = {
    Environment = "development"
    CostCenter  = "engineering"
  }
}
```

### Production Environment (Full Featured)

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  endpoints = {
    # Gateway endpoints
    s3 = {
      service = "s3"
      type    = "Gateway"
    }
    dynamodb = {
      service = "dynamodb"
      type    = "Gateway"
    }

    # Interface endpoints with full monitoring
    ecr-api = {
      service = "ecr.api"
      type    = "Interface"
    }
    ecr-dkr = {
      service = "ecr.dkr"
      type    = "Interface"
    }
    ecs = {
      service = "ecs"
      type    = "Interface"
    }
    ecs-agent = {
      service = "ecs-agent"
      type    = "Interface"
    }
    ecs-telemetry = {
      service = "ecs-telemetry"
      type    = "Interface"
    }
    logs = {
      service = "logs"
      type    = "Interface"
    }
    monitoring = {
      service = "monitoring"
      type    = "Interface"
    }
    ssm = {
      service = "ssm"
      type    = "Interface"
    }
    kms = {
      service = "kms"
      type    = "Interface"
    }
    secretsmanager = {
      service = "secretsmanager"
      type    = "Interface"
    }
    sts = {
      service = "sts"
      type    = "Interface"
    }
  }

  tags = {
    Environment = "production"
    CostCenter  = "engineering"
    Backup      = "required"
  }
}
```

## 🔍 Accessing Outputs

### Using Module Outputs

```hcl
# Get all endpoints information
output "all_endpoints" {
  value = module.vpc_endpoints.vpc_endpoints
}

# Get only gateway endpoints
output "gateway_endpoints" {
  value = module.vpc_endpoints.gateway_endpoints
}

# Get only interface endpoints
output "interface_endpoints" {
  value = module.vpc_endpoints.interface_endpoints
}

# Get endpoint count
output "endpoint_count" {
  value = module.vpc_endpoints.endpoint_count
}

# Get security group ID
output "vpc_endpoints_sg" {
  value = module.vpc_endpoints.security_group_id
}
```

## 📝 Available Services

### Gateway Endpoints (Free)

-   `s3` - Simple Storage Service
-   `dynamodb` - DynamoDB

### Interface Endpoints (Paid - ~$7.20/month each)

-   `ecr.api` - Elastic Container Registry API
-   `ecr.dkr` - Elastic Container Registry Docker
-   `ecs` - Elastic Container Service
-   `ecs-agent` - ECS Agent
-   `ecs-telemetry` - ECS Telemetry
-   `logs` - CloudWatch Logs
-   `monitoring` - CloudWatch Monitoring
-   `ssm` - Systems Manager
-   `ssmmessages` - Systems Manager Messages
-   `ec2messages` - EC2 Messages
-   `kms` - Key Management Service
-   `secretsmanager` - Secrets Manager
-   `sts` - Security Token Service

## 🎯 Best Practices

1. **Start Small**: Begin with essential endpoints and add more as needed
2. **Use Gateway Endpoints**: Always enable S3 and DynamoDB gateway endpoints (they're free)
3. **Monitor Costs**: Track data processing costs in addition to base endpoint costs
4. **Environment-Specific**: Use different endpoint configurations for different environments
5. **Security**: Add IAM policies to restrict access when needed
6. **Naming**: Use descriptive names for endpoints to match your service architecture

## 🚨 Migration from Old Structure

If you're migrating from the old boolean-based structure:

### Old Structure (Deprecated)

```hcl
# OLD WAY - Don't use this
enable_s3_endpoint = true
enable_ecr_api_endpoint = true
enable_ecr_dkr_endpoint = true
```

### New Structure (Recommended)

```hcl
# NEW WAY - Use this
endpoints = {
  s3 = {
    service = "s3"
    type    = "Gateway"
  }
  ecr-api = {
    service = "ecr.api"
    type    = "Interface"
  }
  ecr-dkr = {
    service = "ecr.dkr"
    type    = "Interface"
  }
}
```

The new structure provides much more flexibility and is easier to maintain!
