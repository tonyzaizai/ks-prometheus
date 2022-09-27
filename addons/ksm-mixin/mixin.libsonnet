(import 'kube-state-metrics-mixin/config.libsonnet') +
(import 'alerts.libsonnet') + {
    _config+: {
        ksmGroupLabels: 'cluster,namespace,service',
    },
}