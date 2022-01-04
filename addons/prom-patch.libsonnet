{
  prometheus+: {
    local mixinConfig = super._config.mixin._config,
    mixin:: (import './prom-mixin/mixin.libsonnet') + {
      _config+:: mixinConfig,
    },

    clusterRole+: {
      rules: [
        {
          apiGroups: [''],
          resources: [
            'nodes/metrics',
            'nodes',
            'services',
            'endpoints',
            'pods',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: ['extensions'],
          resources: ['ingresses'],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: ['networking.k8s.io'],
          resources: ['ingresses'],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          nonResourceURLs: ['/metrics'],
          verbs: ['get'],
        },
      ],
    },
    roleSpecificNamespaces:: {}, // Hide it because the clusterRole above contains all permissions
    roleBindingSpecificNamespaces:: {}, // Hide it because the clusterRole above contains all permissions
  },
}