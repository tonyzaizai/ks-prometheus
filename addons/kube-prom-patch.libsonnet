{
  kubePrometheus+: {
    mixin:: (import './kube-prom-mixin/mixin.libsonnet'),
  },
}