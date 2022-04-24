// generate config
local kp0 = (import 'kubesphere.libsonnet') +
  (import './addons/static-etcd.libsonnet') +
  (import './addons/k8s-monitor-patch.libsonnet') +
  (import './addons/am-config.libsonnet') +
  (import './addons/node-exporter-patch.libsonnet') +
  (import './addons/ksm-patch.libsonnet') +
  (import './addons/prom-patch.libsonnet') +
  (import './addons/affinity.libsonnet') +
  (import './addons/resources.libsonnet') +
  (import './addons/storages.libsonnet') +
  (import './addons/grafana-patch.libsonnet') +
  {
    values+:: {
      common+:: {
        namespace: 'kubesphere-monitoring-system',
        images+:: {
          alertmanager: 'prom/alertmanager:v' + $.values.common.versions.alertmanager,
          kubeStateMetrics: 'kubesphere/kube-state-metrics:v' + $.values.common.versions.kubeStateMetrics,
          nodeExporter: 'prom/node-exporter:v' + $.values.common.versions.nodeExporter,
          prometheus: 'prom/prometheus:v' + $.values.common.versions.prometheus,
          prometheusOperator: 'kubesphere/prometheus-operator:v' + $.values.common.versions.prometheusOperator,
          prometheusOperatorReloader: 'kubesphere/prometheus-config-reloader:v' + $.values.common.versions.  prometheusOperator,
          kubeRbacProxy: 'kubesphere/kube-rbac-proxy:v' + $.values.common.versions.kubeRbacProxy,
        },
      },
      etcd+:: {
        ips+: [],
        clientCA: '',
        clientKey: '',
        clientCert: '',
      },
      kubernetesControlPlane+:: {
        mixin+:: {
          _config+:: {
            cadvisorSelector: 'job="kubelet"',
            kubeletSelector: 'job="kubelet"',
            kubeCoreDNSSelector: 'job="coredns"',
          },
        },
      },
      prometheus+:: {
        ruleSelector: {
          matchLabels: $.values.common.ruleLabels,
        },
      },
      thanosRuler+:: {
        name: 'kubesphere',
        alertmanagersUrl: ['dnssrv+http://alertmanager-operated.' + self.namespace + '.svc:9093'],
        queryEndpoints: ['prometheus-operated.' + self.namespace + '.svc:9090'],
        ruleSelector: {
          matchLabels: {
            'role': 'alert-rules',
            'thanos-ruler': 'kubesphere',
          },
        },
      },
    },
  };

// Batch tuning for specific kinds of resources
local kp = std.mapWithKey(
  function(f1, v1)
    if f1 == 'values' then v1
    else std.mapWithKey(function(f2, v2) if v2 != null then v2 + if 'kind' in v2 then {
      // add name prefix to clusterroles and clusterrolebindings
      local clusterRoleNamePrefix = 'kubesphere-',
      [if v2.kind == 'ClusterRole' || v2.kind == 'ClusterRoleBinding' then 'metadata']+: {
        name: clusterRoleNamePrefix + super.name,
      },
      [if v2.kind == 'ClusterRoleBinding' then 'roleRef']+: {
        [if v2.roleRef.name != 'system:auth-delegator' then 'name']: clusterRoleNamePrefix + super.name, // ignoring k8s built-in clusterroles
      },
      // add servicemonitor selector labels.
      local serviceMonitorSelectorLabels = {'app.kubernetes.io/vendor': 'kubesphere'},
      [if v2.kind == 'ServiceMonitor' then 'metadata']+: {
        labels+: serviceMonitorSelectorLabels,
      },
      // [if v2.kind == 'Prometheus' then 'spec']+: {serviceMonitorSelector: {matchLabels: serviceMonitorSelectorLabels}},
      // set servicemonitor scrape interval to 1m
      [if v2.kind == 'ServiceMonitor' && 'spec' in v2 then 'spec']+: {
        [if 'endpoints' in v2.spec then 'endpoints']: std.map(function(ep) ep {interval: '1m'}, v2.spec.endpoints),
      },
      // Set apiVersion of PodDisruptionBudget to policy/v1beta1 in order to achieve wider compatibility. 
      // PodDisruptionBudget was promoted to policy/v1 starting with k8s 1.21, and the v1beta1 one will be removed in 1.25+, refer to https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.21.md#api-change-2
      [if v2.kind == 'PodDisruptionBudget' then 'apiVersion']: 'policy/v1beta1',
    }, v1),
kp0);

// organize configuration output
local manifests =
// { 'namespace/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['prometheus-operator/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator/prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator/prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus/kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager/alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
// { ['blackbox-exporter/blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana/grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics/kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes/kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter/node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ [if std.length(std.findSubstr('Etcd', name) + std.findSubstr('etcd', name)) > 0 then 'etcd/prometheus-' + name else 'prometheus/prometheus-' + name]:
    kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
// { ['prometheus-adapter/prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['thanos-ruler/thanos-ruler-' + name]: kp.thanosRuler[name] for name in std.objectFields(kp.thanosRuler)};

local kustomizationResourceFile(name) = './manifests/' + name + '.yaml';
local kustomization = {
  apiVersion: 'kustomize.config.k8s.io/v1beta1',
  kind: 'Kustomization',
  resources: std.map(kustomizationResourceFile, std.objectFields(manifests)),
};

manifests {
  '../kustomization': kustomization,
}