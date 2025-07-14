# Deploying Docker Containers on Amazon ECS with Terraform and CloudFront

_A comprehensive guide to building a scalable, secure, and cost-effective containerized application deployment using AWS ECS Fargate, Application Load Balancer, and CloudFront CDN_

## Introduction

In this blog post, we'll explore how to deploy a containerized application on Amazon ECS (Elastic Container Service) using Terraform as Infrastructure as Code (IaC), while exposing the application through an Application Load Balancer (ALB) and Amazon CloudFront for global content delivery and enhanced security.

We'll walk through a complete implementation that demonstrates best practices for container orchestration, infrastructure automation, and secure web application deployment on AWS.

## Architecture Overview

Our architecture consists of several key components:

```
Internet → CloudFront → Internal ALB → ECS Fargate Tasks
    ↓                       ↓                ↓
Internet Gateway     Private Subnets   External APIs
    ↓                       ↓          (via NAT Gateway)
Public Subnets         VPC Endpoints
    ↓
NAT Gateway
```

### Key Components:

1. **Amazon ECS Fargate**: Serverless container compute engine
2. **Internal Application Load Balancer (ALB)**: Layer 7 load balancer in private subnets
3. **Amazon CloudFront**: Global CDN for improved performance and security
4. **Amazon ECR**: Managed Docker container registry
5. **AWS CodeBuild**: Automated Docker image building and deployment
6. **VPC with Private/Public Subnets**: Network isolation and security
7. **VPC Endpoints**: Secure AWS service communication without internet gateway

## Project Structure

Our project follows a modular Terraform structure:

```
currency-convertor-ecs/
├── app/
│   ├── main.py           # FastAPI application
│   ├── Dockerfile        # Container definition
│   └── requirements.txt  # Python dependencies
├── infra/
│   ├── main.tf          # Main Terraform configuration
│   ├── variables.tf     # Input variables
│   ├── outputs.tf       # Output values
│   └── modules/
│       ├── ecr/         # ECR repository module
│       ├── ecs-fargate/ # ECS Fargate service module
│       ├── codebuild.docker/ # CodeBuild automation
│       └── vpc-endpoints/    # VPC endpoints module
└── BLOG.md              # This blog post
```

## Application: Currency Converter API

Our sample application is a FastAPI-based currency converter that provides:

-   **Health Check Endpoint** (`/health`): Returns service status and host information
-   **Currency Conversion Endpoint** (`/convert`): Converts between currencies using external API

```python
from fastapi import FastAPI, Query
import requests
import socket
from datetime import datetime, timezone, timedelta

app = FastAPI()

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "host_ip": get_host_ip(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/convert")
def convert_currency(
    from_currency: str = Query(..., alias="from"),
    to_currency: str = Query(..., alias="to"),
    amount: float = Query(...),
):
    # Implementation details...
```

## Step 1: Containerizing the Application

### Dockerfile Best Practices

Our Dockerfile follows security and efficiency best practices:

```dockerfile
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

# Security: Run as non-root user
RUN adduser --disabled-password apiuser
USER apiuser

EXPOSE 8080

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

ENTRYPOINT ["uvicorn", "main:app"]
CMD ["--host", "0.0.0.0", "--port", "8080"]
```

**Key Security Features:**

-   Non-root user execution
-   Minimal base image (slim variant)
-   Built-in health checks
-   Environment variable optimization

## Step 2: Infrastructure as Code with Terraform

### VPC and Network Configuration

We start by creating a secure VPC with public and private subnets:

```terraform
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-${var.environment_name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for key, value in local.azs : cidrsubnet(local.vpc_cidr, 8, key)]
  public_subnets  = [for key, value in local.azs : cidrsubnet(local.vpc_cidr, 8, key + 4)]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_flow_log    = true

  tags = local.tags
}
```

### VPC Endpoints for Secure Communication

To ensure our ECS tasks in private subnets can communicate with AWS services without traversing the internet:

```terraform
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  route_table_ids = module.vpc.private_route_table_ids

  endpoints = {
    ecr-api       = { service = "ecr.api", type = "Interface" }
    ecr-dkr       = { service = "ecr.dkr", type = "Interface" }
    ecs           = { service = "ecs", type = "Interface" }
    logs          = { service = "logs", type = "Interface" }
    s3            = { service = "s3", type = "Gateway" }
  }
}
```

### ECR Repository

Amazon ECR provides a secure, managed Docker registry:

```terraform
module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
  tags            = var.tags
}
```

### ECS Fargate Service

The heart of our container orchestration:

```terraform
module "ecs_fargate" {
  source = "./modules/ecs-fargate"

  project_name           = var.project_name
  environment_name       = var.environment_name
  container_image        = local.container_image
  container_port         = var.container_port

  # Resource allocation
  cpu           = var.ecs_task_cpu
  memory        = var.ecs_task_memory
  desired_count = var.ecs_desired_count

  # Network configuration
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnets
  alb_subnet_ids = module.vpc.private_subnets  # Internal ALB uses private subnets

  # Security
  enable_public_ip = false
  enable_load_balancer = true
}
```

## Step 3: Application Load Balancer Configuration

Our ALB is configured with security features to prevent direct access:

```terraform
resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = true   # Internal ALB - only accessible via CloudFront
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.alb_subnet_ids
}

**Security Benefits of Internal ALB:**
- **No Direct Internet Access**: Internal ALB is only accessible from within the VPC
- **CloudFront-Only Access**: Traffic must route through CloudFront edge locations
- **Reduced Attack Surface**: No direct exposure to internet-based attacks
- **Private Subnet Deployment**: ALB resides in private subnets for enhanced security

# Default action: Deny direct access
resource "aws_lb_listener" "default" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Access Denied</h1><p>Direct access not allowed. Please use the CloudFront URL.</p>"
      status_code  = "403"
    }
  }
}

# Allow CloudFront traffic with custom header
resource "aws_lb_listener_rule" "cloudfront_access" {
  listener_arn = aws_lb_listener.default.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    http_header {
      http_header_name = "X-CloudFront-Secret"
      values           = [random_password.cloudfront_secret.result]
    }
  }
}
```

## Step 4: CloudFront Distribution

CloudFront provides global edge locations, SSL termination, and enhanced security. **Important**: CloudFront can access internal ALBs directly, making this a secure architecture where only CloudFront can reach your application load balancer.

```terraform
resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name = aws_lb.this.dns_name
    origin_id   = "ALB-${var.project_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Secure communication with ALB
    custom_header {
      name  = "X-CloudFront-Secret"
      value = random_password.cloudfront_secret.result
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB-${var.project_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]
      cookies {
        forward = "none"
      }
    }

    # API responses shouldn't be cached
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

## Step 5: Automated CI/CD with CodeBuild

AWS CodeBuild automates our container building and deployment process:

```yaml
# buildspec.yml
version: 0.2

phases:
    pre_build:
        commands:
            - echo Logging in to Amazon ECR...
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

    build:
        commands:
            - echo Build started on `date`
            - echo Building the Docker image...
            - docker build -t $ECR_REPOSITORY_NAME .
            - docker tag $ECR_REPOSITORY_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest

    post_build:
        commands:
            - echo Build completed on `date`
            - echo Pushing the Docker image...
            - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest
            - echo Updating ECS service...
            - aws ecs update-service --cluster $ECS_CLUSTER_NAME --service $ECS_SERVICE_NAME --force-new-deployment
```

## Security Best Practices Implemented

### 1. Network Security

-   **Private Subnets**: ECS tasks run in private subnets with no direct internet access
-   **Internal ALB**: Load balancer deployed in private subnets, inaccessible from internet
-   **VPC Endpoints**: Secure communication with AWS services
-   **Security Groups**: Least privilege access control

### 2. Application Security

-   **Non-root Container**: Application runs as unprivileged user
-   **Custom Headers**: CloudFront-ALB communication secured with secret headers
-   **HTTPS Enforcement**: CloudFront redirects HTTP to HTTPS

### 3. Access Control

-   **Internal ALB Only**: Load balancer only accessible via CloudFront, no direct internet access
-   **Custom Headers**: CloudFront-ALB communication secured with secret headers
-   **IAM Roles**: Least privilege permissions for ECS tasks and CodeBuild

## CloudFront Security Model

### Why Custom Headers Over IP Restrictions

While it might seem logical to restrict ALB access to CloudFront IP ranges, this approach has limitations:

1. **Security Group Limits**: CloudFront has 50+ IP ranges, exceeding AWS security group rule limits (60 rules max)
2. **Dynamic IP Changes**: CloudFront IP ranges can change, requiring infrastructure updates
3. **Complexity**: Managing large IP range lists increases operational overhead

**Our Recommended Approach:**

-   **Custom Secret Headers**: ALB validates `X-CloudFront-Secret` header with random token
-   **Application-Layer Security**: More reliable than network-layer IP filtering
-   **Scalable**: No security group rule limits
-   **AWS Best Practice**: Recommended by AWS for CloudFront-ALB integration

```terraform
# Generate random secret for CloudFront authentication
resource "random_password" "cloudfront_secret" {
  length  = 32
  special = false
}

# ALB Security Group allows traffic but validates headers
resource "aws_security_group" "alb" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Security enforced by custom headers
    description = "HTTP traffic (access controlled by CloudFront custom headers)"
  }
}
```

### Security in Depth

Even with open security group rules, the architecture remains secure:

1. **Internal ALB**: No direct internet routing to private subnets
2. **Secret Headers**: Only requests with valid headers reach application
3. **Default Deny**: ALB returns 403 for requests without proper headers
4. **HTTPS Termination**: All traffic encrypted via CloudFront

## Deployment Process

### 1. Initialize and Plan

```bash
cd infra
terraform init
terraform plan -var-file="terraform.tfvars"
```

### 2. Apply Infrastructure

```bash
terraform apply -var-file="terraform.tfvars"
```

### 3. Monitor Deployment

The initial CodeBuild process will:

1. Build the Docker image
2. Push to ECR
3. Deploy to ECS
4. Update the service

### 4. Access the Application

After deployment, access your application via:

-   **Primary URL**: `https://{cloudfront-domain}/health`
-   **Convert Currency**: `https://{cloudfront-domain}/convert?from=USD&to=EUR&amount=100`

## Monitoring and Observability

### CloudWatch Integration

The infrastructure includes comprehensive logging:

```terraform
# ECS Service with CloudWatch logs
log_configuration {
  log_driver = "awslogs"
  options = {
    "awslogs-group"         = aws_cloudwatch_log_group.this.name
    "awslogs-region"        = var.region
    "awslogs-stream-prefix" = "ecs"
  }
}
```

### Health Checks

Multiple levels of health checking:

1. **Container Health Check**: Docker HEALTHCHECK instruction
2. **ALB Health Check**: Load balancer target group health checks
3. **ECS Service Health**: Service-level health monitoring

## Cost Optimization

### Fargate Pricing Benefits

-   **No EC2 Management**: Pay only for container resources used
-   **Auto Scaling**: Scale based on demand
-   **Spot Integration**: Use Fargate Spot for cost savings

### Resource Right-sizing

```terraform
# Optimized resource allocation
cpu    = 256   # 0.25 vCPU
memory = 512   # 0.5 GB RAM
```

## Performance Considerations

### CloudFront Benefits

-   **Global Edge Locations**: Reduced latency worldwide
-   **Compression**: Automatic gzip compression
-   **SSL Termination**: Offload SSL processing from ALB

### ECS Optimizations

-   **Service Discovery**: Built-in service mesh capabilities
-   **Rolling Deployments**: Zero-downtime deployments
-   **Auto Scaling**: CPU and memory-based scaling

## Troubleshooting Common Issues

### 1. Security Group Rule Limits

**Error**: `RulesPerSecurityGroupLimitExceeded: The maximum number of rules per security group has been reached`

**Cause**: Attempting to add CloudFront IP ranges (50+ CIDRs) exceeds security group limits (60 rules max)

**Solution**: Use custom headers for security instead of IP restrictions:

```terraform
# Instead of this (causes rule limit error):
cidr_blocks = data.aws_ip_ranges.cloudfront.cidr_blocks

# Use this (recommended approach):
cidr_blocks = ["0.0.0.0/0"]  # Security enforced by custom headers
```

**Why this is secure**: Custom headers provide application-layer security that's more reliable than network-layer IP filtering.

### 2. CodeBuild YAML Parsing Errors

**Error**: `YAML_FILE_ERROR: Expected Commands[5] to be of string type: found subkeys instead`

**Cause**: Complex YAML structures, incorrect indentation, or syntax issues in `buildspec.yml`

**Solution**: Simplify the buildspec.yml structure:

```yaml
version: 0.2

phases:
    install:
        runtime-versions:
            docker: 20
        commands:
            - echo "Installing dependencies..."

    pre_build:
        commands:
            - echo "Pre-build phase..."
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

    build:
        commands:
            - echo "Build phase..."
            - docker build -t $REPOSITORY_URI:$IMAGE_TAG .
```

**Key fixes**:

-   Remove complex error handling (`|| { echo "error"; exit 1; }`)
-   Simplify multiline blocks
-   Use clear indentation (2 spaces per level)
-   Remove `batch` and `on-failure` directives if causing issues

### 3. ECS Service Still Running Bootstrap Image

**Problem**: ECS service shows `public.ecr.aws/docker/library/alpine:latest` instead of your application image

**Cause**: CodeBuild is not properly updating the ECS task definition with the new image

**Solutions**:

1. **Check CodeBuild Task Definition Update**:

```bash
# Verify CodeBuild has correct environment variables
aws codebuild describe-projects --names your-project-name --query 'projects[0].environment.environmentVariables'

# Check if ECS_CLUSTER_NAME and ECS_SERVICE_NAME are set
```

2. **Manual Task Definition Update**:

```bash
# Get your ECR image URI
ECR_URI="123456789.dkr.ecr.us-east-1.amazonaws.com/your-repo:latest"

# Update ECS service manually
aws ecs update-service \
  --cluster your-cluster-name \
  --service your-service-name \
  --task-definition your-task-family:latest \
  --force-new-deployment
```

3. **Fix buildspec.yml** - Ensure it includes proper task definition update:

```yaml
post_build:
    commands:
        -  # Get current task definition
        - CURRENT_TASK_DEF=$(aws ecs describe-services --cluster $ECS_CLUSTER_NAME --service $ECS_SERVICE_NAME --query 'services[0].taskDefinition' --output text)
        -  # Download and update task definition with new image
        - aws ecs describe-task-definition --task-definition $CURRENT_TASK_DEF --query 'taskDefinition' > task-def.json
        - jq --arg IMAGE "$REPOSITORY_URI:$IMAGE_TAG" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)' task-def.json > new-task-def.json
        -  # Register new task definition and update service
        - NEW_TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file://new-task-def.json --query 'taskDefinition.taskDefinitionArn' --output text)
        - aws ecs update-service --cluster $ECS_CLUSTER_NAME --service $ECS_SERVICE_NAME --task-definition $NEW_TASK_DEF_ARN
```

### 4. ECS Service Won't Start

```bash
# Check ECS service events
aws ecs describe-services --cluster {cluster-name} --services {service-name}

# Check CloudWatch logs
aws logs get-log-events --log-group-name {log-group}
```

### 5. ALB Health Check Failures

-   Verify container port matches target group port
-   Check security group ingress rules
-   Validate health check endpoint response

### 6. CloudFront "Failed to contact the origin" Error

**Error**: `Failed to contact the origin` when accessing CloudFront URL

**This is a common issue with internal ALB + CloudFront setup. Follow these diagnostic steps:**

#### **Step 1: Verify ALB is Running and Healthy**
```bash
# Check ALB status
aws elbv2 describe-load-balancers --names your-project-alb --query 'LoadBalancers[0].{State:State.Code,DNS:DNSName,Scheme:Scheme}'

# Check target group health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/your-tg/id
```

#### **Step 2: Test ALB Directly (Internal Access)**
```bash
# From an EC2 instance in the same VPC or via AWS CloudShell
curl -H "X-CloudFront-Secret: your-secret-value" http://internal-alb-dns-name/health

# Check if ALB responds to requests with custom header
```

#### **Step 3: Verify ECS Service is Running**
```bash
# Check ECS service status
aws ecs describe-services --cluster your-cluster --services your-service --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Check ECS tasks
aws ecs list-tasks --cluster your-cluster --service-name your-service
aws ecs describe-tasks --cluster your-cluster --tasks task-arn
```

#### **Step 4: Check CloudFront Configuration**
```bash
# Get CloudFront distribution details
aws cloudfront get-distribution --id your-distribution-id --query 'Distribution.DistributionConfig.Origins.Items[0]'

# Verify origin domain name matches ALB DNS name
```

#### **Step 5: Common Issues and Fixes**

**Issue 1: ECS Service Not Running**
- Check if CodeBuild successfully updated the service
- Verify container image exists in ECR
- Check ECS service events for errors

**Issue 2: ALB Not Responding**
- Verify ALB is in "active" state
- Check target group has healthy targets
- Verify security groups allow traffic

**Issue 3: CloudFront Configuration**
- Ensure origin domain name matches ALB DNS exactly
- Verify custom header is configured correctly
- Check origin protocol policy (should be "http-only" for internal ALB)

**Issue 4: Network Connectivity**
- Internal ALB requires CloudFront to have network path
- Verify VPC configuration allows CloudFront access
- Check route tables and NACLs

#### **Quick Fix Commands**

```bash
# Force ECS service deployment
aws ecs update-service --cluster your-cluster --service your-service --force-new-deployment

# Check CloudFront distribution status
aws cloudfront get-distribution --id your-distribution-id --query 'Distribution.Status'

# Get ALB listener rules
aws elbv2 describe-rules --listener-arn your-listener-arn
```

#### **Manual Testing Steps**

1. **Test Container Locally**:
```bash
docker run -p 8080:8080 your-ecr-repo:latest
curl http://localhost:8080/health
```

2. **Test ALB Health Check**:
```bash
# Check ALB target group settings
aws elbv2 describe-target-groups --target-group-arns your-tg-arn --query 'TargetGroups[0].HealthCheckPath'
```

3. **Verify CloudFront Origin**:
- Go to CloudFront console
- Check origin domain name matches ALB DNS
- Verify custom headers are configured

**Expected Resolution**: After fixes, CloudFront should return your application's health check response instead of the origin error.

## Scaling and Production Considerations

### Horizontal Scaling

```terraform
# Auto Scaling configuration
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

### Multi-Environment Setup

```hcl
# Environment-specific configurations
environments/
├── dev/
│   └── terraform.tfvars
├── staging/
│   └── terraform.tfvars
└── prod/
    └── terraform.tfvars
```

### Security Enhancements

-   **AWS WAF**: Add web application firewall
-   **AWS Shield**: DDoS protection
-   **Custom SSL Certificates**: Use ACM certificates for custom domains
-   **AWS Secrets Manager**: Manage sensitive configuration

## Conclusion

This implementation demonstrates a production-ready, secure, and scalable approach to deploying containerized applications on AWS. By leveraging ECS Fargate, we eliminate server management overhead while maintaining full control over our application environment.

The combination of Terraform for infrastructure management, CodeBuild for CI/CD automation, and CloudFront for global content delivery creates a robust foundation for modern web applications.

### Key Benefits Achieved:

1. **Scalability**: Auto-scaling based on demand
2. **Security**: Multiple layers of protection
3. **Performance**: Global edge locations via CloudFront
4. **Maintainability**: Infrastructure as Code with Terraform
5. **Cost Effectiveness**: Pay-per-use Fargate pricing
6. **Reliability**: Multi-AZ deployment with health checks

### Next Steps:

-   Implement custom domain with SSL certificates
-   Add AWS WAF for enhanced security
-   Set up monitoring and alerting with CloudWatch
-   Implement blue-green deployments
-   Add database integration (RDS, DynamoDB)
-   Configure custom auto-scaling policies

This architecture serves as a solid foundation that can be extended and customized based on specific application requirements while maintaining security and operational best practices.

---

_This implementation showcases modern cloud-native development practices using AWS managed services, ensuring your applications are secure, scalable, and maintainable from day one._

## Network Requirements with Internal ALB

**Important**: Even with an internal ALB, we still need certain network components:

#### Required Components:

1. **Internet Gateway**: Still needed for:

    - CodeBuild to download Docker base images and packages
    - NAT Gateway to provide outbound internet access

2. **NAT Gateway**: Required for:

    - ECS tasks calling external APIs (our app calls `api.frankfurter.app`)
    - AWS CLI commands during CodeBuild
    - Container image pulls from public registries

3. **Public Subnets**: Needed for:
    - NAT Gateway placement
    - CodeBuild projects (can run in public subnets)

#### What Changed with Internal ALB:

-   **ALB Traffic**: No longer needs Internet Gateway (CloudFront accesses it directly)
-   **Security**: Reduced attack surface - ALB not exposed to internet
-   **Cost**: Same infrastructure cost (NAT Gateway still required)

```terraform
module "vpc" {
  # Network gateways
  enable_nat_gateway = true  # Still needed for ECS tasks to access external APIs
  single_nat_gateway = true  # Cost optimization for dev/test environments

  # Internet Gateway automatically created for public subnets
  # Still needed for: CodeBuild, ECS external API calls (via NAT)

  private_subnets = [...]  # ECS tasks and internal ALB
  public_subnets  = [...]  # NAT Gateway placement
}
```

#### Alternative: Fully Private Architecture

To eliminate internet dependencies entirely, you would need:

-   Replace external API calls with internal services
-   Use private container registries only
-   Use CodeBuild with VPC configuration in private subnets
-   This significantly increases complexity and cost
