terraform {
  required_version = ">= 1.5.0"

  required_providers {
    mgc = {
      source  = "magalucloud/mgc"
      version = "~> 0.46.0"
    }
  }
}
