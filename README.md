# Demo-Magic Script VMware Cloud-Native-Runtimes

This demo-magic script will install the following solutions, as VMware Packages (Carvel), automagically 🪄

## Prerequisites - General

* internet access is required in order to add the public Tanzu Packages repository (`tanzu package repository add`)
* the biggest part of the necessary prerequisites is the relocation of the Tanzu Packages for Tanzu Application Platform as well as for RabbitMQ
  * perform these steps first! [Installing Tanzu Application Platform package and profiles](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install.html#add-the-tanzu-application-platform-package-repository-1)
  * Perform the relocation task for the [RabbitMQ package repository](https://docs.vmware.com/en/VMware-Tanzu-RabbitMQ-for-Kubernetes/1.3/tanzu-rmq/GUID-installation.html#install-the-packagerepository) as well
  * you can find a how-to-guide here - [LINK](https://rguske.github.io/post/deploy-tanzu-packages-from-a-private-registry/#making-packages-offline-available)
* the installation of the Tanzu RabbitMQ Package from the VMware repository requires a valid [Tanzu Network](https://network.pivotal.io/) account
* a running Kubernetes cluster with enough capacity (compute)
  * I'd recommend at least 3x large worker-nodes (e.g. 4-8 vCPUs and 8 - 16GB vRAM each)
* a configured default `StorageClass` in Kubernetes (for the `pvc`'s created by Tanzu RabbitMQ)
  * `kubectl patch storageclass gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
* a Load Balancer solution in place
  * we need VIP's for various services (like e.g. Sockeye)
* the possibility to configure a [DNS Wildcard Record](https://en.wikipedia.org/wiki/Wildcard_DNS_record)
  * adjust the `domain_name` value in the `values.yaml` with your data
* an existing vSphere Tag (mine: `backup-basic-sla`) which will be used by the example tagging-function in the script
  * I also created a dedicated service-user (`svc-tagging`) which will be used by the tagging operation
  * adjust the values in the `tag_secret.json` file with your tag and user data
* a `ReadOnly` user in vSphere which we'll use in order to connect the `VsphereSource` to the vCenter Server (Event API)

### Prerequisites - CLI

* the `demo-magic` scripts requires pipeviewer (`pv`) - [Install](https://formulae.brew.sh/formula/pv) `pv` using `brew`
* installed Knative (`kn`) CLI - [LINK](https://knative.dev/docs/client/install-kn/)
* `kn vsphere` [Plugin installed](https://github.com/vmware-tanzu/sources-for-knative/tree/main/plugins/vsphere) - [LINK](https://github.com/vmware-tanzu/sources-for-knative/releases)
  * download the binary and `mv` it to `/usr/local/bin/` (on Linux)
* I'm also using the cli fun-tools `figlet` as well as `lolcat` within the script
  * `brew install` ...


## VMware Packages and Versions

The following Cloud-Native-Runtimes (CNR) Packages will install the two Knative Building-Blocks `Serving` and `Eventing`:

| NAME | PACKAGE-NAME | PACKAGE-VERSION |
|:--|:--:|:--:|
| cloud-native-runtimes | cnrs.tanzu.vmware.com         | 2.0.1                 |
| eventing              | eventing.tanzu.vmware.com     | 2.0.1                 |

Specific versions which are included in both above listed Packages:

| Name | Release Version |
|:--|:--:|
| Knative Serving | 1.3.2 |
| Knative Eventing | 1.3.2 |
| Knative Eventing RabbitMQ Integration | 1.3.1 |
| VMware Tanzu Sources for Knative | 1.3.0 |
| TriggerMesh Sources from Amazon Web Services (SAWS) | 1.6.0 |
| vSphere Event Sources | 1.3.0 |

Additional installed VMware Packages which are necessary and a prerequisite:

| NAME | PACKAGE-NAME | PACKAGE-VERSION |
|:--|:--:|--:|
| cert-manager          | cert-manager.tanzu.vmware.com | 1.7.2+vmware.1-tkg.1  |
| contour               | contour.tanzu.vmware.com      | 1.20.2+vmware.1-tkg.1 |

Also, it'll install a new rabbitmq-cluster deployment (using the Tanzu-RabbitMQ Operator), a RabbitMQ-Broker for Knative, a new Tanzu Source for Knative (vSphere Source) as well as an example PowerCLI function.

## Resources

* [Cloud Native Runtimes](https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/index.html)
* [Download CNR](https://network.pivotal.io/products/serverless/)
* [VMware Tanzu Sources for Knative](https://github.com/vmware-tanzu/sources-for-knative)
* [Tanzu RabbitMQ](https://docs.vmware.com/en/VMware-Tanzu-RabbitMQ-for-Kubernetes/index.html)
* [VMware OSS Project VMware Event Broker Appliance](https://vmweventbroker.io/)
* [Example Functions](https://github.com/vmware-samples/vcenter-event-broker-appliance/tree/development/examples)
