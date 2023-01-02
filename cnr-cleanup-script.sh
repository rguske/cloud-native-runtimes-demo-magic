#!/bin/bash

set -euo pipefail

kubectl -n vmware-functions delete -f - <<EOF
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
EOF

kubectl -n vmware-functions delete secret tag-secret

kubectl -n vmware-functions delete -f - <<EOF
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
EOF

kn vsphere source delete --name vcsa-source -n vmware-functions

kn vsphere auth delete --name vcsa-ro-creds -n vmware-functions

kubectl delete -f - <<EOF
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
    namespace: tanzu-rabbitmq
  delivery:
    retry: 2
    backoffPolicy: linear
EOF

kubectl delete -f - <<EOF
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
    rabbitmq.com/topology-allowed-namespaces: "vmware-functions"
spec:
  replicas: 1
  imagePullSecrets:
  - name: tanzu-rabbitmq-registry-creds
EOF

kubectl -n tanzu-rabbitmq-package delete -f - <<EOF
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
EOF

kubectl delete -f - <<EOF
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
  - "*"
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - "*"
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - "*"
- apiGroups:
  - cert-manager.io
  resources:
  - certificates
  - issuers
  verbs:
  - "*"
- apiGroups:
  - ""
  resources:
  - configmaps
  - namespaces
  - secrets
  - serviceaccounts
  - services
  verbs:
  - "*"
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - clusterrolebindings
  - clusterroles
  - rolebindings
  - roles
  verbs:
  - "*"
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - "*"
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
  - "*"
  verbs:
  - "*"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tanzu-rabbitmq-sa
  namespace: tanzu-rabbitmq-package
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
  namespace: tanzu-rabbitmq-package
EOF

kubectl delete -f - <<EOF
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: tanzu-rabbitmq-registry-creds
  namespace: tanzu-rabbitmq-package
spec:
  toNamespaces:
  - '*'
EOF

kubectl delete secret tanzu-rabbitmq-registry-creds -n tanzu-rabbitmq-package

tanzu package repository delete tanzu-rabbitmq-repo --namespace tanzu-rabbitmq-package -y

kubectl delete ns tanzu-rabbitmq

kubectl delete ns tanzu-rabbitmq-package

kubectl delete ns vmware-functions

tanzu package installed delete eventing --namespace tap-install -y

tanzu package installed delete cloud-native-runtimes --namespace tap-install -y

kubectl delete ns tap-install

kubectl delete -f - <<EOF
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
EOF

kubectl delete -f - <<EOF
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
EOF