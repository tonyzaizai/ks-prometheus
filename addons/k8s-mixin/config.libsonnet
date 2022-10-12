(import 'kubernetes-mixin/config.libsonnet') + {
  _config+:: {
    kubeApiserverSelector: 'job="apiserver"',
    kubeCoreDNSSelector: 'job="coredns"',
    prometheusSelector: 'job="prometheus"',
    kubeProxy: false,
  },
}