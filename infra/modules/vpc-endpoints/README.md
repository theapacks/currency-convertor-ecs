# VPC Endpoints Module

This module dynamically creates VPC endpoints for AWS services commonly used with ECS Fargate deployments. VPC endpoints allow your ECS tasks to communicate with AWS services without traversing the public internet, improving security and reducing data transfer costs.

## 🚀 Features

-   **Dynamic Endpoint Creation**: Configurable endpoints for 15+ AWS services
-   **ECS Fargate Optimized**: Essential endpoints for ECR, ECS, and CloudWatch
-   **Cost Optimization**: Enable only the endpoints you need
-   **Security First**: Proper security groups and IAM policies
-   **Gateway & Interface**: Supports both gateway and interface endpoint types

## 📋 Supported Endpoints

### Gateway Endpoints (Free)

-   **S3**: Required for ECR image layers
-   **DynamoDB**: For application data storage

### Interface Endpoints (Charged)

-   **ECR API**: Container registry API calls
-   **ECR DKR**: Docker image pulls
-   **ECS**: ECS service management
-   **ECS Agent**: Task communication
-   **ECS Telemetry**: Monitoring data
-   **CloudWatch Logs**: Application logging
-   **CloudWatch Monitoring**: Metrics and alarms
-   **Systems Manager (SSM)**: Parameter store, secrets
-   **KMS**: Encryption key management
-   **Secrets Manager**: Application secrets
-   **STS**: Security token service

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                           VPC                               │
│  ┌─────────────────┐              ┌─────────────────────┐   │
│  │  Private Subnet │              │   Public Subnet     │   │
│  │                 │              │                     │   │
│  │  ┌─────────────┐│              │  ┌─────────────────┐│   │
│  │  │ ECS Tasks   ││              │  │ Load Balancer   ││   │
│  │  └─────────────┘│              │  └─────────────────┘│   │
│  └─────────────────┘              └─────────────────────┘   │
│           │                                  │               │
│           │                                  │               │
│  ┌─────────────────┐              ┌─────────────────────┐   │
│  │ VPC Endpoints   │              │   Internet Gateway  │   │
│  │ ┌─────────────┐ │              │                     │   │
│  │ │ECR API/DKR  │ │              └─────────────────────┘   │
│  │ │ECS Services │ │                         │               │
│  │ │CloudWatch   │ │                         │               │
│  │ │S3 Gateway   │ │                         │               │
│  │ └─────────────┘ │                         │               │
│  └─────────────────┘                         │               │
└─────────────────────────────────────────────────────────────┘
                                                │
                                         ┌─────────────┐
                                         │ AWS Services│
                                         └─────────────┘
```

## 🔧 Usage

### Basic Usage (ECS Fargate Essentials)

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  # Essential for ECS Fargate
  enable_s3_endpoint             = true
  enable_ecr_api_endpoint        = true
  enable_ecr_dkr_endpoint        = true
  enable_ecs_endpoint            = true
  enable_logs_endpoint           = true

  tags = local.tags
}
```

### Advanced Usage (Full Featured)

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  # Gateway endpoints (no additional cost)
  enable_s3_endpoint             = true
  enable_dynamodb_endpoint       = true

  # Interface endpoints (additional cost)
  enable_ecr_api_endpoint        = true
  enable_ecr_dkr_endpoint        = true
  enable_ecs_endpoint            = true
  enable_ecs_agent_endpoint      = true
  enable_ecs_telemetry_endpoint  = true
  enable_logs_endpoint           = true
  enable_monitoring_endpoint     = true
  enable_ssm_endpoint            = true
  enable_kms_endpoint            = true
  enable_secrets_manager_endpoint = true

  # Optional: Restrict access with IAM policy
  policy_restriction = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:userid" = ["AIDAEXAMPLE", "AROAEXAMPLE:session-name"]
          }
        }
      }
    ]
  })

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

## 💰 Cost Considerations

### Gateway Endpoints (FREE)

-   S3 and DynamoDB gateway endpoints are free
-   Only charged for data transfer

### Interface Endpoints (PAID)

-   **Base cost**: ~$7.20/month per endpoint (24/7 uptime)
-   **Data processing**: $0.01 per GB processed
-   **Example monthly costs** (eu-west-2):
    -   ECR API + DKR: ~$14.40
    -   ECS endpoints (3): ~$21.60
    -   CloudWatch Logs: ~$7.20
    -   **Total for ECS setup**: ~$43.20/month

### Cost Optimization Tips

1. **Start minimal**: Enable only essential endpoints
2. **Monitor usage**: Use CloudWatch to track data processing
3. **Consider alternatives**: Public subnets + NAT Gateway might be cheaper for low-traffic applications
4. **Use gateway endpoints**: Always enable S3 and DynamoDB gateway endpoints (free)

## 🛡️ Security Features

### Network Security

-   Dedicated security group for VPC endpoints
-   Restricts access to VPC CIDR blocks only
-   Separate from application security groups

### IAM Policies

-   Optional policy restrictions on endpoint usage
-   Support for condition-based access control
-   Principal-based access restrictions

### DNS Resolution

-   Private DNS enabled for interface endpoints
-   Seamless integration with existing applications
-   No code changes required

## 🚀 Getting Started

### Prerequisites

-   VPC with private subnets
-   Route tables configured
-   ECS tasks in private subnets (recommended)

### Step 1: Enable Essential Endpoints

```hcl
# Minimum configuration for ECS Fargate
enable_s3_endpoint      = true  # Free - for ECR image layers
enable_ecr_api_endpoint = true  # Paid - for registry API
enable_ecr_dkr_endpoint = true  # Paid - for image pulls
enable_logs_endpoint    = true  # Paid - for CloudWatch logs
```

### Step 2: Deploy and Test

```bash
# Deploy the infrastructure
./tf.sh init --env=dev
./tf.sh plan --env=dev
./tf.sh apply --env=dev

# Test endpoint connectivity from ECS task
aws sts get-caller-identity  # Should work without internet
aws ecr get-login-password   # Should work through VPC endpoint
```

### Step 3: Monitor and Optimize

-   Check CloudWatch metrics for endpoint usage
-   Monitor data processing costs
-   Add/remove endpoints based on actual usage

## 🔍 Monitoring

### CloudWatch Metrics

The module automatically creates endpoints with monitoring. Key metrics to watch:

-   `AWS/VpcFlowLogs/PacketsToEndpoint`
-   `AWS/VpcFlowLogs/BytesToEndpoint`
-   `AWS/ECS/Service/CPUUtilization`
-   `AWS/ECS/Service/MemoryUtilization`

### Cost Monitoring

-   Enable Cost Explorer for VPC endpoint costs
-   Set up billing alerts for unexpected charges
-   Review monthly data processing charges

## 🐛 Troubleshooting

### Common Issues

#### ECS Tasks Can't Pull Images

```bash
# Check ECR endpoints
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=*ecr*"

# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

#### DNS Resolution Problems

```bash
# From ECS task, test DNS resolution
nslookup ecr.api.eu-west-2.amazonaws.com
nslookup ecr.dkr.eu-west-2.amazonaws.com
```

#### High Costs

-   Review data processing charges in Cost Explorer
-   Consider using public subnets + NAT Gateway for high-traffic applications
-   Disable unused endpoints

### Debug Commands

```bash
# List all VPC endpoints
aws ec2 describe-vpc-endpoints

# Check endpoint status
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxxxxxx

# Test connectivity from ECS task
curl -I https://ecr.api.eu-west-2.amazonaws.com
```

## 🔄 Migration Strategy

### From Public Subnets

1. Create VPC endpoints
2. Move ECS tasks to private subnets
3. Update security groups
4. Remove NAT Gateway (if no longer needed)

### From NAT Gateway

1. Calculate current NAT Gateway costs
2. Compare with VPC endpoint costs
3. Create endpoints gradually
4. Monitor cost impact
5. Migrate or keep NAT based on cost analysis

## 📚 References

-   [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-endpoints.html)
-   [ECS VPC Endpoints Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html)
-   [VPC Endpoints Pricing](https://aws.amazon.com/vpc/pricing/)
-   [ECR VPC Endpoints](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html)
