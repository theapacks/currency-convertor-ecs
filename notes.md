## App

### Local

python3 -m venv venv
source venv/bin/activate

uvicorn main:app --reload

pip install -r requirements.txt

curl "http://127.0.0.1:8000/convert?from=GBP&to=ZAR&amount=1"
curl "http://127.0.0.1:8000/health"

curl "http://currency-convertor-ecs-alb-1060759041.eu-west-2.elb.amazonaws.com:8080/health"

### Docker

docker build -t currency-convertor-api .

trivy image --exit-code 1 --severity CRITICAL,HIGH currency-convertor-api:latest

docker scout recommendations --tag 3.13-slim

docker scout cves local://currency-convertor-api:latest

docker run -d -p 8000:80 --name convertor-api currency-convertor-api

curl "http://127.0.0.1:8000/convert?from=GBP&to=ZAR&amount=1"

docker stop convertor-api && docker rm convertor-api

## Infra

aws sso login --sso-session sifast

terraform plan -var-file="terraform.tfvars" -var="aws_profile=SifastDevAdmin2" -out=planfile -target=module.ecr

terraform plan -var-file="terraform.tfvars" -var="aws_profile=SifastDevAdmin2" -out=planfile -target=module.codebuild_docker

terraform plan -var-file="terraform.tfvars" -var="aws_profile=SifastDevAdmin2" -out=planfile

trivy config --config trivy.yaml .

## Troubleshooting

curl https://d305otuo479fef.cloudfront.net/health

internal-currency-convertor-ecs-alb-549054593.eu-west-2.elb.amazonaws.com
curl -H "X-CloudFront-Secret: 1lV1ZUPoklZtOCcC1rQB27eBOgkUC5ka" http://internal-currency-convertor-ecs-alb-549054593.eu-west-2.elb.amazonaws.com/health

aws cloudfront get-distribution --id E3S8NDRYN0A2IE --query 'Distribution.DistributionConfig.Origins.Items[0]'

# ECS Service troubleshooting

aws ecs list-services --cluster currency-convertor-ecs-test-ecs-cluster --profile SifastDevAdmin2

aws ecs describe-services --cluster currency-convertor-ecs-test-ecs-cluster --services currency-convertor-ecs-test-ecs-cluster-service --profile SifastDevAdmin2

aws ecs list-tasks --cluster currency-convertor-ecs-test-ecs-cluster --service-name currency-convertor-ecs-test-ecs-cluster-service --profile SifastDevAdmin2

aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names currency-convertor-ecs-test-alb-tg --query 'TargetGroups[0].TargetGroupArn' --output text --profile SifastDevAdmin2) --profile SifastDevAdmin2

# CloudFront troubleshooting

aws cloudfront create-invalidation --distribution-id E4YH6U1BCSWCO --paths "/health" --profile SifastDevAdmin2

# Check CloudFront distribution status

aws cloudfront get-distribution --id E4YH6U1BCSWCO --query 'Distribution.Status' --profile SifastDevAdmin2

# Test with cache-busting parameter

curl "https://d305otuo479fef.cloudfront.net/health?$(date +%s)"

timeout 10 telnet internal-currency-convertor-ecs-alb-549054593.eu-west-2.elb.amazonaws.com 80

timeout 10 nc -zv internal-currency-convertor-ecs-alb-549054593.eu-west-2.elb.amazonaws.com 80
