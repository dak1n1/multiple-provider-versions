terraform {
  required_providers {
    # This is the locally compiled version of the provider, based on the current branch.
    # It's used to test changes in the local branch.
    kubernetes-local = {
      source = "localhost/test/kubernetes"
      version = "9.9.9"
    }
    # The following block configures the latest released version of the provider, which is needed for a sub-module of this config.
    # This configuration is a work-around, because we don't have control over the module's required_providers blocks.
    # A "required_providers" block needs to be added to all sub-modules in order to use a custom "source" and "version".
    # Otherwise, the sub-module will use defaults, which in our case means an empty provider config.
    kubernetes-released = {
      source = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
  }
}

provider "kubernetes-released" {
  config_path = "~/.kube/config"
}

# In order to differentiate between the two providers, this one uses a separate Kubernetes cluster.
provider "kubernetes-local" {
  config_path = "~/.kube/second"
}

# This module is a simulation of a community owned module, with its own separate required_providers.
module "community-module" {
  providers =  {kubernetes = kubernetes-released}
  source    = "./community-module"
}

# This module is a simulation of one that we own, which tests our local provider.
module "kubernetes-test" {
  providers =  {kubernetes = kubernetes-local}
  source    = "./kubernetes-test"
}
