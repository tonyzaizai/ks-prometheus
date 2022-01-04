(import 'kubernetes-mixin/config.libsonnet') + {
  _config+:: {
    kubeCoreDNSSelector: 'job="coredns"',
    prometheusSelector: 'job="prometheus"',
  },
}