local defaults = {
  local defaults = self,
  namespace:: error 'must provide namespace',
  commonLabels:: {
    'app.kubernetes.io/name': 'kube-prometheus',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  mixin:: {
    ruleLabels: {},
    _config: {
      ksApiserverSelector: 'job="ks-apiserver"',
    },
  },
};

function(params) {
  local ks = self,
  _config:: defaults + params,
  _metadata:: {
    labels: ks._config.commonLabels,
    namespace: ks._config.namespace,
  },

  mixin::
    (import './kubesphere-mixin/mixin.libsonnet') + {
      _config+:: ks._config.mixin._config,
    },

  serviceMonitorKsApiserver: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: ks._metadata {
      name: 'ks-apiserver',
      namespace: ks._config.namespace,
      labels+: { 'app.kubernetes.io/name': 'ks-apiserver' },
    },
    spec: {
      selector: {
        matchLabels: {'app': 'ks-apiserver'},
      },
      namespaceSelector: {
        matchNames: ['kubesphere-system'],
      },
      endpoints: [{
        targetPort: 9090,
        interval: '1m',
        path: '/kapis/metrics',
        relabelings: [{
          action: 'labeldrop',
          regex: '(endpoint)',
        }],
      }],
    },
  },

  serviceMonitorKsControllerManager: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: ks._metadata {
      name: 'ks-controller-manager',
      namespace: ks._config.namespace,
      labels+: { 'app.kubernetes.io/name': 'ks-controller-manager' },
    },
    spec: {
      selector: {
        matchLabels: {'app': 'ks-controller-manager'},
      },
      namespaceSelector: {
        matchNames: ['kubesphere-system'],
      },
      endpoints: [{
        targetPort: 8080,
        interval: '1m',
        path: '/kapis/metrics',
        relabelings: [{
          action: 'labeldrop',
          regex: '(endpoint)',
        }],
      }],
    },
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: ks._metadata {
      name: 'kubesphere',
      namespace: ks._config.namespace,
      labels+: ks._config.mixin.ruleLabels,
    },
    spec: {
      local r = if std.objectHasAll(ks.mixin, 'prometheusRules') then ks.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(ks.mixin, 'prometheusAlerts') then ks.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },
}