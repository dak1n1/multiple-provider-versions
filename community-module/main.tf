# This module represents a module owned by a community, where I can't modify required_providers.

terraform {
  required_providers {
    kubernetes = ">= 1.11.1"
  }
}

resource kubernetes_namespace "test" {
  metadata {
    name = "released-test"
  }
}
