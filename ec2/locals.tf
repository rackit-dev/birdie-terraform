locals {
  name   = "birdie-${basename(path.cwd)}"
  region = "ap-northeast-2"
  state_bucket = "birdie-terraform-state-bucket"
  ami = "ami-024ea438ab0376a47"
  key_name = "birdie-key"
}