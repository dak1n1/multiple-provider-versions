# Bug reproducer: multiple versions of a Terraform provider

## Overview

This repo reproduces a bug in Terraform 0.15-beta2 where it is no longer possible to specify multiple versions of a provider in the same config.

It uses both an "in-house" provider, which is stored in the local filesystem cache, and an official released version of the provider.

## Running the reproducer

### Setting up the environment

Set up two minikube clusters. If needed, you can download minikube using the curl command below.

```
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x ./minikube

export KUBECONFIG="$HOME/.kube/config"
./minikube start -p first

export KUBECONFIG="$HOME/.kube/second"
./minikube start -p second
```

Ensure that Minikube successfully created the kubeconfig files. These will be used in our Terraform config.

```
ls ~/.kube/config
ls ~/.kube/second
```

Download a copy of the Kubernetes provider and save it in your filesystem cache.

```
OS_ARCH="$(go env GOOS)_$(go env GOARCH)"
curl -Lo k8sprovider.zip https://releases.hashicorp.com/terraform-provider-kubernetes/2.0.3/terraform-provider-kubernetes_2.0.3_${OS_ARCH}.zip
unzip terraform-provider-kubernetes_v2.0.3_x5
mkdir -p /tmp/.terraform.d/localhost/test/kubernetes/9.9.9/${OS_ARCH}
mv terraform-provider-kubernetes_v2.0.3_x5 /tmp/.terraform.d/localhost/test/kubernetes/9.9.9/${OS_ARCH}/terraform-provider-kubernetes_9.9.9_${OS_ARCH}
```

### Demonstration of current behavior with 0.14.7 (works)

Full debug logs are available for [init](logs/debug_0.14.7_init.txt) and [apply](logs/debug_0.14.7_apply.txt).

```
$ TF_CLI_CONFIG_FILE="$PWD/.terraformrc" terraform0.14.7 init
Initializing modules...

Initializing the backend...

Initializing provider plugins...
- Finding localhost/test/kubernetes versions matching "9.9.9"...
- Finding hashicorp/kubernetes versions matching ">= 1.11.1, >= 2.0.2"...
- Installing localhost/test/kubernetes v9.9.9...
- Installed localhost/test/kubernetes v9.9.9 (unauthenticated)
- Installing hashicorp/kubernetes v2.0.3...
- Installed hashicorp/kubernetes v2.0.3 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

The apply succeeds.

```
$ TF_CLI_CONFIG_FILE="$PWD/.terraformrc" terraform0.14.7 apply --auto-approve
module.community-module.kubernetes_namespace.test: Creating...
module.community-module.kubernetes_namespace.test: Creation complete after 0s [id=released-test]
module.kubernetes-test.kubernetes_namespace.test: Creating...
module.kubernetes-test.kubernetes_namespace.test: Creation complete after 1s [id=local-test]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

One namespace appears on each cluster. This represents one resource created by each of the two provider versions.

```
$ unset KUBECONFIG
$ minikube kubectl get ns
NAME              STATUS   AGE
released-test     Active   3m28s

$ minikube profile second
$ minikube kubectl get ns
NAME              STATUS   AGE
local-test        Active   3m39s
```

Alternatively, if kubectl is installed, it can be used directly to verify resources are created.

```
$ kubectl --kubeconfig=/home/dakini/.kube/second get ns local-test
NAME         STATUS   AGE
local-test   Active   8s

$ kubectl --kubeconfig=/home/dakini/.kube/config get ns released-test
NAME            STATUS   AGE
released-test   Active   19s
```

### Demonstration of current behavior with 0.15-beta2 (fails)

Full debug logs are available for [init](logs/debug_0.15-beta2_init.txt).
```
$ TF_CLI_CONFIG_FILE="$PWD/.terraformrc" terraform0.15.0-beta2 init
Initializing modules...
- community-module in community-module
- kubernetes-test in kubernetes-test
There are some problems with the configuration, described below.

The Terraform configuration must be valid before initialization so that
Terraform can determine which modules and providers need to be installed.
╷
│ Error: Invalid type for provider module.community-module.provider["registry.terraform.io/hashicorp/kubernetes"]
│
│   on main.tf line 31, in module "community-module":
│   31:   providers =  {kubernetes = kubernetes-released}
│
│ Cannot use configuration from provider["registry.terraform.io/hashicorp/kubernetes-released"] for
│ module.community-module.provider["registry.terraform.io/hashicorp/kubernetes"]. The given provider configuration is for a different provider type.
╵

╷
│ Error: Invalid type for provider module.kubernetes-test.provider["localhost/test/kubernetes"]
│
│   on main.tf line 37, in module "kubernetes-test":
│   37:   providers =  {kubernetes = kubernetes-local}
│
│ Cannot use configuration from provider["registry.terraform.io/hashicorp/kubernetes-local"] for module.kubernetes-test.provider["localhost/test/kubernetes"]. The
│ given provider configuration is for a different provider type.
╵
```
