locals {

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  container_image = try(
    data.aws_ecr_image.image.image_uri,
    "public.ecr.aws/docker/library/alpine:latest"
  )
  tags = {
    Project = "currency-convertor"
  }
}