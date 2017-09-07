terraform {
  backend "s3" {
    key = "build-requester-vcs.tfstate"
    region = "us-west-2"
  }
}
