output "uploaded_files" {
  description = "Map of uploaded file keys and their S3 URIs"
  value = {
    for key, obj in aws_s3_object.files : key => "s3://${aws_s3_bucket.this.id}/${obj.key}"
  }
}
