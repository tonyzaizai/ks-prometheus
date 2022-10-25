(import 'rules/prom.libsonnet') +

((import 'github.com/prometheus/prometheus/documentation/prometheus-mixin/mixin.libsonnet') +
{
  prometheusAlerts+:: {
    groups: std.map(function(g) 
      g + {
        rules: std.map(
          function(r) if r.alert != 'PrometheusNotConnectedToAlertmanagers' then r else r + {
            // rewrite expr for PrometheusNotConnectedToAlertmanagers rule compatible with prometheus agent mode
            expr: |||
              sum without(rule_group) (prometheus_rule_group_rules{%(prometheusSelector)s}) > 0
              and
              max_over_time(prometheus_notifications_alertmanagers_discovered{%(prometheusSelector)s}[5m]) < 1
            ||| % $._config,
          },
          super.rules)
      }, 
    super.groups)
  }
}) +

(import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') +
{
  _config+:: {
    // kubeClusterLabel is used to identify a kubernetes cluster.
    kubeClusterLabel: 'cluster',
  }
}