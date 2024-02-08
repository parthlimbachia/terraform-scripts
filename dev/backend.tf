terraform {
  backend "s3" {
    bucket  = "streamocracy-tfstate"
    region  = "us-east-1"
    encrypt = true
    key     = "streamocracy-dev.tfstate"
  }
}
