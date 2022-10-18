(import 'rules/prom.libsonnet') +
(import 'github.com/prometheus/prometheus/documentation/prometheus-mixin/mixin.libsonnet') +
(import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') +
{
  _config+:: {
    // kubeClusterLabel is used to identify a kubernetes cluster.
    kubeClusterLabel: 'cluster',
  }
}