# Run this manually first: terraform -chdir=bootstrap apply
resource "aws_s3_bucket" "tfstate" {
  bucket        = "task-platform-tfstate-${random_id.suffix.hex}"
  force_destroy = true   # easy cleanup when done
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "task-platform-tf-locks"
  billing_mode = "PAY_PER_REQUEST"   # no provisioned capacity cost
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucket_name" { value = aws_s3_bucket.tfstate.bucket }
