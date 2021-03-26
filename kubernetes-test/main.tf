terraform {
  required_providers {
    kubernetes = {
      source = "localhost/test/kubernetes"
      version = "9.9.9"
    }
  }
}

# This should be created on the second cluster because it uses config_path "~/.kube/second".
# In this module, we control the required_providers, so we specify the localhost/test/kubernetes provider.

resource kubernetes_namespace "test" {
  metadata {
    name = "local-test"
  }
}
