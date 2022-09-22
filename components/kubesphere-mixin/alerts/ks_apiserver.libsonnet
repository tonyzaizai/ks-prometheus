local utils = import 'kubernetes-mixin/lib/utils.libsonnet';

{
  _config+:: {
    ksApiserverSelector: error 'must provide selector for ks-apiserver',

    kubeConfigCertExpirationWarningSeconds: 7 * 24 * 3600,
    kubeConfigCertExpirationCriticalSeconds: 1 * 24 * 3600,
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'ks-apiserver',
        rules: [{
          alert: 'ksApiSlow',
          annotations: {
            summary: 'ks-apiserver requests are slow.',
            message: '99th percentile of requests is {{ $value }}s on ks-apiserver instance {{ $labels.instance }} for {{ $labels.verb }} {{ $labels.resource }}.{{ $labels.group }}/{{ $labels.version }}'
          },
          expr: |||
            histogram_quantile(0.99, sum by(instance,group,resource,verb,version,le) (rate(ks_server_request_duration_seconds_bucket{group!="terminal.kubesphere.io", %(ksApiserverSelector)s}[5m]))) > 5
          ||| % $._config,
          'for': '10m',
          labels: {
            severity: 'critical'
          },
        },
          (import 'kubernetes-mixin/lib/absent_alert.libsonnet') {
            componentName:: 'ksApiserver',
            selector:: $._config.ksApiserverSelector,
          },
        ],
      },
    ],
  },
}
