(import 'kube-prometheus/addons/static-etcd.libsonnet') + {
  etcd+: {
    mixin+: {
      ruleLabels: $.values.common.ruleLabels,
      _config+: {
        etcdSelector: 'job=~".*etcd.*"',
        etcd_instance_labels: 'instance',
      },
    },
  },
  prometheus+: {
     local p = self,
     mixinEtcd::
       (import './etcd-mixin/mixin.libsonnet') + {
         _config+:: $.etcd.mixin._config,
       },
     rulesEtcd: {
       apiVersion: 'monitoring.coreos.com/v1',
       kind: 'PrometheusRule',
       metadata: {
         labels: { 'app.kubernetes.io/name': 'etcd' } + $.etcd.mixin.ruleLabels,
         name: 'prometheus-k8s-etcd-rules', # keep the name the same as that in previous versions of kubesphere
         namespace: $.values.common.namespace, # keep the namespace the same as that in previous versions of kubesphere
       },
       spec: {
         local r = if std.objectHasAll(p.mixinEtcd, 'prometheusRules') then p.mixinEtcd.prometheusRules.groups else [],
         local a = if std.objectHasAll(p.mixinEtcd, 'prometheusAlerts') then p.mixinEtcd.prometheusAlerts.groups else [],
         groups: a + r,
       },
     },

     serviceMonitorEtcd+: {
       metadata+: {
         namespace: $.values.common.namespace, # keep the namespace the same as that in previous versions of kubesphere
       },
     },
  },
}