# Demo-Magic Script VMware Cloud-Native-Runtimes

This demo-magic script will install the following solutions, as VMware Packages (Carvel), automagically 🪄

## Prerequisites

* the biggest part of the necessary prerequisites is the relocation of the Tanzu Packages for Tanzu Application Platform
  * Perform these steps first! [Installing Tanzu Application Platform package and profiles](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install.html#add-the-tanzu-application-platform-package-repository-1)
* running Kubernetes cluster with enough capacity (compute)
  * I'd recommend at least two large worker-nodes (e.g. 2-4 vCPUs and 8 - 16GB vRAM each)
* a configured default `StorageClass` in Kubernetes
  * `kubectl patch storageclass gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
  * we need `persistentVolumes` for RabbitMQ
* a Load Balancer solution in place
  * we need VIP's for various services
* the possibility to configure a [DNS Wildcard Record](https://en.wikipedia.org/wiki/Wildcard_DNS_record)
* an existing vSphere Tag (mine: `backup-basic-sla`) which will be used by the example tagging-function in the script
  * I also created a dedicated service-user (`svc-tagging`) which will be used by the tagging operation
* a `ReadOnly` user in vSphere which we'll use in order to connect the `VsphereSource` to the vCenter Server (Event API)
* installed Knative (`kn`) CLI - [LINK](https://knative.dev/docs/client/install-kn/)
* `kn vsphere` [Plugin installed](https://github.com/vmware-tanzu/sources-for-knative/tree/main/plugins/vsphere) - [LINK](https://github.com/vmware-tanzu/sources-for-knative/releases)
  * download the binary and `mv` it to `/usr/local/bin/` (on Linux)
* internet access is required

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
