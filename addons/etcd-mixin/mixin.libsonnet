(import 'config.libsonnet') +
(import 'rules.libsonnet') +
{
  prometheusAlerts+:: (import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet').prometheusAlerts,
}