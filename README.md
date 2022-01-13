# ks-prometheus

Inspired by [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus.git), ks-prometheus maintains KubeSphere's customization of the entire Prometheus monitoring stack including prometheus-operator, Prometheus configuration and rules, kube-state-metrics, and node-exporter.

## Install

Config files provided by default are in [`./manifests`](./manifests) dir and have been tested for compatibility with a specific version of KubeSphere. They may be installed by the following command according to your KubeSphere version.  
```shell
kubectl apply -k ./kustomization.yaml
```

## Custom config files

Maybe you want to customize some of configs, or disable some addons,  after which you can get new configs by the following steps: 
- First install or update some tools and dependencies:  
    ```shell
    make update
    ```
- Then build to generate config files
    ```shell
    make manifests
    ```
> You have to test new configs for compatiblity with KubeSphere by yourself, especially when upgrading component versions.