(import 'kubernetes-mixin/alerts/alerts.libsonnet') + {
    prometheusAlerts+: {
        groups: std.filterMap(
            function(g) $._config.kubeProxy || g.name != 'kubernetes-system-kube-proxy', 
            function(g) if g.name != 'kubernetes-apps' then g else g + {
                  rules: std.map(function(r) r + {
                      expr: std.strReplace(super.expr, 'kube_daemonset_updated_number_scheduled', 'kube_daemonset_status_updated_number_scheduled'),
                      }, 
                    super.rules),
                }, 
            super.groups),
    },
}