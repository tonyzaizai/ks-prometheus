(import 'apps_alerts.libsonnet') +
(import 'resource_alerts.libsonnet') +
(import 'storage_alerts.libsonnet') +
(import 'system_alerts.libsonnet') +
(import 'kube_apiserver.libsonnet') +
(import 'kubelet.libsonnet') +
(import 'kubernetes-mixin/alerts/kube_scheduler.libsonnet') +
(import 'kubernetes-mixin/alerts/kube_controller_manager.libsonnet') +
(import 'kubernetes-mixin/alerts/kube_proxy.libsonnet') +
(import 'kubernetes-mixin/lib/add-runbook-links.libsonnet') + {
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