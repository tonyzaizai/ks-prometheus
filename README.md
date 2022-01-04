# ks-prometheus

This repo based [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus.git), manages and updates the cluster monitoring stack deployed on top of [KubeSphere](https://github.com/kubesphere/kubesphere.git).

## Install

Config files provided by default are in [`./manifests`](./manifests) dir and have been tested for compatibility with a specific version of KubeSphere. They may be installed by `kubectl apply -k ./kustomization.yaml` according to your KubeSphere version, but it is strongly recommended that you [enable the monitoring component plugin](https://kubesphere.com.cn/en/docs/quick-start/enable-pluggable-components/) to install them into KubeSphere, beacause the latter is more convenient and contains more adaptive works.

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