#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${BLUE}➜ ${BLUE}\W "

read PRIVATE_REGISTRY_PASSWORD

# hide the evidence
clear

# Export Registry and Repository Variales
pei "export INSTALL_REGISTRY_USERNAME=admin \
export INSTALL_REGISTRY_PASSWORD='VMware1!' \
export INSTALL_REGISTRY_HOSTNAME='registry.cloud-garage.net' \
export TAP_VERSION=1.3.0 \
export INSTALL_REPO=rguske/tap-packages"

# print out Tanzu Packages
pei "figlet Preperations - Tanzu Packages  | lolcat"

# Add the Tanzu Standard Repository
pei "tanzu package repository add tanzu-standard --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.0 -n tkg-system"

# Show available packages
pe "tanzu package available list -n tkg-system"

# Install Cert-Manager
pe "kubectl create -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager-sa
  namespace: tkg-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: cert-manager-sa
    namespace: tkg-system
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: cert-manager
  namespace: tkg-system
spec:
  serviceAccountName: cert-manager-sa
  packageRef:
    refName: cert-manager.tanzu.vmware.com
    versionSelection:
      constraints: 1.7.2+vmware.1-tkg.1
  values:
  - secretRef:
      name: cert-manager-data-values
---
apiVersion: v1
kind: Secret
metadata:
  name: cert-manager-data-values
  namespace: tkg-system
stringData:
  values.yml: |
    ---
    namespace: cert-manager
EOF"

# Install Contour
pe "kubectl create -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: contour-sa
  namespace: tkg-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: contour-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: contour-sa
    namespace: tkg-system
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: contour
  namespace: tkg-system
spec:
  serviceAccountName: contour-sa
  packageRef:
    refName: contour.tanzu.vmware.com
    versionSelection:
      constraints: 1.20.2+vmware.1-tkg.1
  values:
  - secretRef:
      name: contour-values
---
apiVersion: v1
kind: Secret
metadata:
  name: contour-values
  namespace: tkg-system
stringData:
  values.yaml: |
    contour:
     configFileContents: {}
     useProxyProtocol: false
     replicas: 2
     pspNames: vmware-system-restricted
     logLevel: info
    envoy:
     service:
       type: LoadBalancer
       annotations: {}
       nodePorts:
         http: null
         https: null
       externalTrafficPolicy: Cluster
       disableWait: false
     hostPorts:
       enable: false
       http: 80
       https: 443
     hostNetwork: false
     terminationGracePeriodSeconds: 300
     logLevel: info
     pspNames: null
    certificates:
     duration: 8760h
     renewBefore: 360h
EOF"

# Show Load Balancer IP assignment for Envoy
pei "kubectl -n tanzu-system-ingress get svc"

# Show DNS Wildcard Config for CNR
pei "figlet DNS Wildcard Config | lolcat"

# Create TAP Namespace
pe "kubectl create ns tap-install"

# Create Registry Secret using Secretgen-Ctrl
pe "tanzu secret registry add tap-registry \
--username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
--server ${INSTALL_REGISTRY_HOSTNAME} \
--export-to-all-namespaces --yes \
--namespace tap-install"

# Add the new Package Repository
pe "tanzu package repository add tanzu-tap-repo \
--url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:$TAP_VERSION \
--namespace tap-install"

# Check the Repository Config
pe "tanzu package repository get tanzu-tap-repo \
--namespace tap-install"

# Check CNR version availability
pe "tanzu package available get cnrs.tanzu.vmware.com --namespace tap-install"

# Show CNR value file
pe "cat values.yaml"

# Install the CNR Package
pe "tanzu package install cloud-native-runtimes \
-p cnrs.tanzu.vmware.com \
-v 2.0.1 \
-n tap-install \
-f values.yaml \
--poll-timeout 30m"

# Check Eventing version availability
pe "tanzu package available get eventing.tanzu.vmware.com --namespace tap-install"

# Install the Eventing Package
pe "tanzu package install eventing \
-p eventing.tanzu.vmware.com \
-v 2.0.1 \
-n tap-install \
--poll-timeout 30m"

# Create vmware-functions namespace
pe "kubectl create ns vmware-functions"

# Create tanzu-rabbitmq namespace
pe "kubectl create ns tanzu-rabbitmq-package"

# Add Tanzu-RabbitMQ Package Repository
pe "kubectl -n tanzu-rabbitmq-package create -f - <<EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: tanzu-rabbitmq-repo
spec:
  fetch:
    imgpkgBundle:
      image: registry.cloud-garage.net/jmanzaneque/tanzu-rabbitmq-package-repo:1.3.1
EOF"

# Create Registry Secret for the Tanzu-RabbitMQ Repository
pe "kubectl create -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: tanzu-rabbitmq-registry-creds
  namespace: tanzu-rabbitmq-package
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      'auths': {
        'registry.cloud-garage.net': {
          'username': 'rguske',
          'password': '${PRIVATE_REGISTRY_PASSWORD}',
          'auth': ''
        }
      }
    }
EOF"

# Export the Secret to every Namespace
pe "kubectl create -f - <<EOF
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: tanzu-rabbitmq-registry-creds
  namespace: tanzu-rabbitmq-package
spec:
  toNamespaces:
  - '*'
EOF"

# Create Tanzu-RabbitMQ SA
pe "kubectl create -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tanzu-rabbitmq-crd-install
rules:
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - validatingwebhookconfigurations
  - mutatingwebhookconfigurations
  verbs:
  - '*'
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - '*'
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - '*'
- apiGroups:
  - cert-manager.io
  resources:
  - certificates
  - issuers
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - configmaps
  - namespaces
  - secrets
  - serviceaccounts
  - services
  verbs:
  - '*'
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - clusterrolebindings
  - clusterroles
  - rolebindings
  - roles
  verbs:
  - '*'
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - get
  - patch
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  verbs:
  - create
  - get
  - list
  - update
  - watch
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - update
  - watch
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - create
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - create
  - delete
  - get
  - list
  - update
  - watch
- apiGroups:
  - rabbitmq.com
  - rabbitmq.tanzu.vmware.com
  resources:
  - '*'
  verbs:
  - '*'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tanzu-rabbitmq-sa
  namespace: tanzu-rabbitmq
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tanzu-rabbitmq-crd-install-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tanzu-rabbitmq-crd-install
subjects:
- kind: ServiceAccount
  name: tanzu-rabbitmq-sa
  namespace: tanzu-rabbitmq
EOF"

# Create Tanzu-RabbitMQ PackageInstall
pe "kubectl -n tanzu-rabbitmq create -f - <<EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: tanzu-rabbitmq
spec:
  serviceAccountName: tanzu-rabbitmq-sa
  packageRef:
    refName: rabbitmq.tanzu.vmware.com
    versionSelection:
      constraints: 1.3.1
  values:
  - secretRef:
      name: tanzu-rabbitmq-values
---
apiVersion: v1
kind: Secret
metadata:
  name: tanzu-rabbitmq-values
stringData:
  values.yml: |
    ---
    namespace: rabbitmq-system
EOF"

# Createthe first RabbitMQ Cluster
pe "kubectl create -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: tanzu-rabbitmq-registry-creds
  namespace: tanzu-rabbitmq
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: tanzu-rabbitmq-cl-1
  namespace: tanzu-rabbitmq
  annotations:
    rabbitmq.com/topology-allowed-namespaces: 'vmware-functions'
spec:
  replicas: 1
  imagePullSecrets:
  - name: tanzu-rabbitmq-registry-creds
EOF"

# Create the RabbitMQ Broker for Knative
pe "kubectl -f - <<EOF
---
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: rabbitmq-broker
  namespace: vmware-functions
  annotations:
    eventing.knative.dev/broker.class: RabbitMQBroker
spec:
  config:
    apiVersion: rabbitmq.com/v1beta1
    kind: RabbitmqCluster
    name: tanzu-rabbitmq-cl-1
    namespace: rabbitmq
  delivery:
    retry: 2
    backoffPolicy: linear
EOF"

# Create a first broker MTChannelBasedBroker
# pe "kubectl -n vmware-functions create -f - <<EOF
# apiVersion: eventing.knative.dev/v1
# kind: Broker
# metadata:
#   annotations:
#     eventing.knative.dev/broker.class: MTChannelBasedBroker
#   name: default
# spec:
#   config:
#     apiVersion: v1
#     kind: ConfigMap
#     name: config-br-default-channel
#     namespace: knative-eventing
# EOF"

# Print out Tanzu Sources for Knative
pei "figlet Tanzu Sources for Knative | lolcat"

# Create an Auth-Secret
pe "kn vsphere auth create \
--namespace vmware-functions \
--username 'kn-ro@cpod-nsxv8.az-stc.cloud-garage.net' \
--password 'VMware1!' \
--name vcsa-cpod-ro-creds \
--verify-url https://vcsa.cpod-nsxv8.az-stc.cloud-garage.net \
--verify-insecure"

# Create a new vSphereSource
pe "kn vsphere source create \
--namespace vmware-functions \
--name vcsa-nsxv8 \
--vc-address https://vcsa.cpod-nsxv8.az-stc.cloud-garage.net \
--skip-tls-verify \
--secret-ref vcsa-cpod-ro-creds \
--sink-uri http://rabbitmq-broker-broker-ingress.vmware-functions.svc.cluster.local \
--encoding json"

# Install Event-Viewer Sockeye
pe "kubectl -n vmware-functions create -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: sockeye
  name: sockeye
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sockeye
  template:
    metadata:
      labels:
        app: sockeye
    spec:
      containers:
      - image: registry.cloud-garage.net/rguske/sockeye:v0.7.0
        name: sockeye
        ports:
          - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: sockeye
  name: sockeye
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: sockeye
  type: LoadBalancer
---
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: sockeye-trigger
spec:
  broker: rabbitmq-broker
  subscriber:
    ref:
      apiVersion: v1
      kind: Service
      name: sockeye
EOF"

# Create tagging Secret
pe "kubectl -n vmware-functions create secret generic tag-secret --from-file=TAG_SECRET=tag_secret.json"

# Create Tagging Function
pe "kubectl -n vmware-functions create -f - <<EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: kn-pcli-tag
  labels:
    app: veba-ui
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale: '1'
        autoscaling.knative.dev/minScale: '1'
    spec:
      containers:
        - image: us.gcr.io/daisy-284300/veba/kn-pcli-tag:1.4
          envFrom:
            - secretRef:
                name: tag-secret
          env:
            - name: FUNCTION_DEBUG
              value: 'false'
---
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: veba-pcli-tag-trigger
  labels:
    app: veba-ui
spec:
  broker: rabbitmq-broker
  filter:
    attributes:
      type: com.vmware.vsphere.DrsVmPoweredOnEvent.v0
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: kn-pcli-tag
EOF"

# wait max 3 seconds until user presses
PROMPT_TIMEOUT=3
wait