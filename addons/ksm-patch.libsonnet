{
  kubeStateMetrics+: {
    local mixinConfig = super._config.mixin._config,
    mixin:: (import './ksm-mixin/mixin.libsonnet') + 
      (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') {
        _config+:: mixinConfig,
      },
      
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            local addArgs(args, name, containers) = std.map(
              function(c) if c.name == name then
                c {
                  args+: args,
                }
              else c,
              containers,
            ),
            containers: addArgs(
              [|||
                --metric-denylist=
                kube_.+_version,
                kube_.+_created,
                kube_deployment_(spec_paused|spec_strategy_rollingupdate_.+),
                kube_endpoint_(info|address_.+),
                kube_job_(info|owner|spec_(parallelism|active_deadline_seconds)|status_(active|.+_time)),
                kube_cronjob_(info|status_.+|spec_.+),
                kube_namespace_(status_phase),
                kube_persistentvolume_(info|capacity_.+),
                kube_persistentvolumeclaim_(resource_.+|access_.+),
                kube_secret_(type),
                kube_service_(spec_.+|status_.+),
                kube_ingress_(info|path|tls),
                kube_replicaset_(status_.+|spec_.+|owner),
                kube_poddisruptionbudget_status_.+,
                kube_replicationcontroller_.+,
                kube_node_info,
                kube_(hpa|replicaset|replicationcontroller)_.+_generation
              |||, 
              '--metric-labels-allowlist=namespaces=[kubesphere.io/workspace]'],
              'kube-state-metrics',
              super.containers
            ),
          },
        },
      },
    },
    serviceMonitor+: {
      spec+: {
        endpoints: std.map(
          function(eps)
            if eps.port != 'https-main' then eps
            else eps + {
              metricRelabelings+: [{
                action: 'replace',
                replacement: '$1',
                targetLabel: 'workspace',
                sourceLabels: ['label_kubesphere_io_workspace'],
                regex: '(.*)',
              }],
            },
        super.endpoints),
      },
    },
  },
}