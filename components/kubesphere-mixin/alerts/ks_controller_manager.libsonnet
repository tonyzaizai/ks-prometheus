local utils = import 'kubernetes-mixin/lib/utils.libsonnet';

{
  _config+:: {
    ksControllerManagerSelector: error 'must provide selector for ks-controller-manager',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'ks-controller-manager',
        rules: [
          (import 'kubernetes-mixin/lib/absent_alert.libsonnet') {
            componentName:: 'ksControllerManager',
            selector:: $._config.ksControllerManagerSelector,
          },
        ],
      },
    ],
  },
}
