local defaults = {
  local defaults = self,
  namespace: error 'must provide namespace',
  image: error 'must provide image',
  version: error 'must provide version',
  resources: {
    requests: { memory: '200Mi' },
  },

  name: error 'must provide name',
  replicas: 2,
  commonLabels:: {
    'app.kubernetes.io/name': 'thanos-ruler',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
    'app.kubernetes.io/component': 'thanos-ruler',
    'app.kubernetes.io/part-of': 'kube-prometheus',
  },
  selectorLabels:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if !std.setMember(labelName, ['app.kubernetes.io/version'])
  },
  ruleNamespaceSelector: null,
  ruleSelector: {},
  evaluationInterval: '1m',
  mixin:: {
    ruleLabels: {},
    _config: {
      thanos: {
        targetGroups: {
          namespace: defaults.namespace,
        },
        rule: {
          selector: 'job="thanos-ruler-' + defaults.name + '",namespace="' + defaults.namespace + '"',
        },
      }
    },
  },
  alertmanagersUrl: [],
  queryEndpoints: [],
};

function(params) {
  local tr = self,
  _config:: defaults + params,
  // Safety check
  assert std.isObject(tr._config.resources),
  assert std.isObject(tr._config.mixin._config),

  mixin::
    (import 'github.com/thanos-io/thanos/mixin/alerts/rule.libsonnet') +
    (import 'github.com/thanos-io/thanos/mixin/alerts/add_runbook_links.libsonnet') + {
      _config+:: tr._config.mixin._config,
      targetGroups+: tr._config.mixin._config.thanos.targetGroups,
      rule+: {
        selector: tr._config.mixin._config.thanos.rule.selector,
        dimensions: 'cluster, ' + super.dimensions,
      },
    },

  [if (defaults + params).replicas > 1 then 'podDisruptionBudget']: {
    apiVersion: 'policy/v1',
    kind: 'PodDisruptionBudget',
    metadata: {
      name: 'thanos-ruler-' + tr._config.name,
      namespace: tr._config.namespace,
      labels: tr._config.commonLabels,
    },
    spec: {
      minAvailable: 1,
      selector: {
        matchLabels: tr._config.selectorLabels,
      },
    },
  },

  thanosRuler: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ThanosRuler',
    metadata: {
      name: tr._config.name,
      namespace: tr._config.namespace,
      labels: tr._config.commonLabels,
    },
    spec: {
      evaluationInterval: tr._config.evaluationInterval,
      replicas: tr._config.replicas,
      image: tr._config.image,
      podMetadata: {
        labels: tr._config.commonLabels,
      },
      ruleNamespaceSelector: tr._config.ruleNamespaceSelector,
      ruleSelector: tr._config.ruleSelector,
      resources: tr._config.resources,
      alertmanagersUrl: tr._config.alertmanagersUrl,
      queryEndpoints: tr._config.queryEndpoints,
    },
  },

  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'thanos-ruler-' + tr._config.name,
      namespace: tr._config.namespace,
      labels: tr._config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'web', targetPort: 'web', port: 10902 },
      ],
      selector: tr._config.selectorLabels,
      sessionAffinity: 'ClientIP',
    },
  },

  serviceMonitor: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata: {
      name: 'thanos-ruler-' + tr._config.name,
      namespace: tr._config.namespace,
      labels: tr._config.commonLabels,
    },
    spec: {
      selector: {
        matchLabels: tr._config.selectorLabels,
      },
      endpoints: [{
        port: 'web',
        interval: '30s',
      }],
    },
  },

  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      labels: tr._config.commonLabels + tr._config.mixin.ruleLabels,
      name: 'thanos-ruler-' + tr._config.name + '-rules',
      namespace: tr._config.namespace,
    },
    spec: {
      local r = if std.objectHasAll(tr.mixin, 'prometheusRules') then tr.mixin.prometheusRules.groups else [],
      local a = if std.objectHasAll(tr.mixin, 'prometheusAlerts') then tr.mixin.prometheusAlerts.groups else [],
      groups: a + r,
    },
  },
}