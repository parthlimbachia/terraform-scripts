terraform {
  backend "s3" {
    bucket  = "streamocracy-tfstate"
    region  = "us-east-2"
    encrypt = true
    key     = "streamocracy-stage.tfstate"
  }
}
