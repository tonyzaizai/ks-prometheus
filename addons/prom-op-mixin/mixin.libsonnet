(import 'prometheus-operator-mixin/config.libsonnet') +
(import 'alerts.libsonnet') + {
    _config+: {
        prometheusOperatorGroupLabels: 'namespace,cluster',
    },
}