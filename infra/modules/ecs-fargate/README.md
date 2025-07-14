# ECS Fargate Module

This module creates an ECS Fargate cluster to host the currency converter application.

## Architecture

The module creates:

-   **ECS Cluster**: Fargate cluster with container insights enabled
-   **ECS Service**: Manages the running tasks
-   **Task Definition**: Defines the container configuration
-   **Application Load Balancer**: Distributes traffic to tasks
-   **Security Groups**: Controls network access
-   **IAM Roles**: For task execution and application permissions
-   **CloudWatch Logs**: For application logging

## Features

-   **Fargate Launch Type**: Serverless container hosting
-   **Application Load Balancer**: High availability and health checking
-   **Auto Scaling**: Ready for horizontal scaling (configure separately)
-   **Health Checks**: Container-level and ALB-level health checks
-   **Logging**: Integrated CloudWatch logs
-   **Security**: Least privilege IAM roles and security groups

## Usage

### Prerequisites

1. **VPC and Subnets**: You need a VPC with at least 2 public subnets for the ALB
2. **ECR Repository**: Must be created first (handled by the ECR module)
3. **Docker Image**: The application image must be pushed to ECR

### Configuration

Update your `terraform.tfvars` file with your VPC details:

```hcl
# Find your VPC ID in AWS Console > VPC > Your VPCs
vpc_id = "vpc-xxxxxxxxxx"

# Find your subnet IDs in AWS Console > VPC > Subnets
# Use public subnets in different availability zones
subnet_ids = [
  "subnet-xxxxxxxxxx",
  "subnet-xxxxxxxxxx"
]
```

### Finding Your VPC and Subnets

#### Option 1: Using AWS CLI

```bash
# Get default VPC
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text

# Get subnets for the VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=YOUR_VPC_ID" --query 'Subnets[*].[SubnetId,AvailabilityZone]' --output table
```

#### Option 2: Using AWS Console

1. Go to AWS Console > VPC
2. Note your VPC ID from "Your VPCs"
3. Go to "Subnets" and select subnets in your VPC
4. Choose subnets in different Availability Zones

#### Option 3: Use Default VPC (Automated)

Uncomment the data sources in `data.tf` and use:

```hcl
# In terraform.tfvars, you can reference:
# vpc_id = data.aws_vpc.default.id
# subnet_ids = data.aws_subnets.default.ids
```

### Deploy the Application

1. **Initialize Terraform**:

    ```bash
    ./tf.sh init --env=dev
    ```

2. **Plan the deployment**:

    ```bash
    ./tf.sh plan --env=dev
    ```

3. **Apply the configuration**:
    ```bash
    ./tf.sh apply --env=dev
    ```

## Accessing the Application

After deployment, you can access the application via:

-   **Load Balancer URL**: Check the `application_url` output
-   **Health Check**: `http://<load-balancer-url>/health`
-   **API Endpoint**: `http://<load-balancer-url>/convert?from=USD&to=EUR&amount=100`

## Monitoring

-   **CloudWatch Logs**: `/ecs/{cluster-name}/{service-name}`
-   **ECS Console**: AWS Console > ECS > Clusters
-   **Application Load Balancer**: AWS Console > EC2 > Load Balancers

## Customization

You can customize the deployment by modifying variables in `terraform.tfvars`:

```hcl
# ECS Configuration
ecs_cluster_name = "my-cluster"
ecs_service_name = "my-service"
ecs_task_cpu = "512"        # 256, 512, 1024, etc.
ecs_task_memory = "1024"    # 512, 1024, 2048, etc.
ecs_desired_count = 2       # Number of tasks to run
container_port = 80         # Port your app listens on
```

## Troubleshooting

### Common Issues

1. **Task fails to start**: Check CloudWatch logs for container errors
2. **Health check failures**: Ensure your app responds to `/health` on the correct port
3. **Can't access application**: Verify security groups and subnet configuration
4. **Image pull errors**: Ensure ECR repository exists and contains the image

### Debugging Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster CLUSTER_NAME --services SERVICE_NAME

# Check task definition
aws ecs describe-task-definition --task-definition FAMILY_NAME

# Check running tasks
aws ecs list-tasks --cluster CLUSTER_NAME --service-name SERVICE_NAME

# View task logs
aws logs tail /ecs/CLUSTER_NAME/SERVICE_NAME --follow
```

## Security

The module follows AWS security best practices:

-   Least privilege IAM roles
-   VPC security groups with minimal required access
-   Container runs as non-root user
-   Logs are encrypted in CloudWatch

## Cost Optimization

-   Uses Fargate Spot instances capability (can be enabled)
-   Minimal resource allocation (256 CPU, 512 MB memory)
-   Short log retention period (7 days)
-   Can be configured for auto-scaling based on demand
