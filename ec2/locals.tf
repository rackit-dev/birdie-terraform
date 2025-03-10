locals {
  name   = "birdie-${basename(path.cwd)}"
  region = "ap-northeast-2"
  state_bucket = "birdie-terraform-state-bucket"
}