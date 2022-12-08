# Demo-Magic Script VMware Cloud-Native-Runtimes

This demo-magic script will install the following solutions automagically:

Packages:

* cert-manager.vmware.com
* contour.vmware.com
* cloud-native-runtimes.vmware.com
* eventing.vmware.com
* tanzu-rabbitmq.vmware.com

Also, it'll install a new rabbitmq-cluster deployment (using the Tanzu-RabbitMQ Operator), a RabbitMQ-Broker for Knative, a new Tanzu Source for Knative (vSphere Source) as well as an example PowerCLI function.