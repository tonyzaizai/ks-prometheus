{
  kubernetesControlPlane+: {
    local mixinConfig = super._config.mixin._config,
    mixin:: (import './k8s-mixin/mixin.libsonnet') + {
      _config+:: mixinConfig + {
        prometheusSelector: $.prometheus._config.mixin._config.prometheusSelector,
      },
    },

    serviceKubeControllerManager: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'kube-controller-manager-svc',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'kube-controller-manager' },
      },
      spec: {
        clusterIP: 'None',
        ports: [{
          name: 'https-metrics',
          port: 10257,
          targetPort: 10257,
        }],
        selector: {
          component: 'kube-controller-manager',
        },
      },
    },

    serviceKubeScheduler: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'kube-scheduler-svc',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'kube-scheduler' },
      },
      spec: {
        clusterIP: 'None',
        ports: [{
          name: 'https-metrics',
          port: 10259,
          targetPort: 10259,
        }],
        selector: {
          component: 'kube-scheduler',
        },
      },
    },

    serviceMonitorKubelet+: {
      spec+: {
        endpoints: [{
          port: 'https-metrics',
          scheme: 'https',
          interval: '1m',
          honorLabels: true,
          tlsConfig: { insecureSkipVerify: true },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [{
            sourceLabels: ['__metrics_path__'],
            targetLabel: 'metrics_path',
          }, {
            action: 'labeldrop',
            regex: '(service|endpoint)'
          },],
          metricRelabelings: [{
            action: 'keep',
            sourceLabels: ['__name__'],
            regex: std.join('|', [
              'kubelet_node_name',
              'kubelet_running_container_count',
              'kubelet_running_pod_count',
              'kubelet_volume_stats.*',
              'kubelet_pleg_relist_duration_seconds_.+',
            ]),
          },],
        }, {
          port: 'https-metrics',
          scheme: 'https',
          path: '/metrics/cadvisor',
          interval: '1m',
          honorLabels: true,
          tlsConfig: { insecureSkipVerify: true },
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [{
            sourceLabels: ['__metrics_path__'],
            targetLabel: 'metrics_path',
          }, {
            action: 'labeldrop',
            regex: '(service|endpoint)'
          },],
          metricRelabelings: [{
            action: 'keep',
            sourceLabels: ['__name__'],
            regex: std.join('|', [
              'container_cpu_usage_seconds_total',
              'container_memory_usage_bytes',
              'container_memory_cache',
              'container_network_.+_bytes_total',
              'container_memory_working_set_bytes',
              'container_cpu_cfs_.*periods_total',
              'container_processes.*',
              'container_threads.*',
            ]),
          },],
        }],
      },
    },

    serviceMonitorKubeScheduler+: {
      spec+: {
        endpoints: [{
          port: 'https-metrics',
          interval: '1m',
          scheme: 'https',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: { insecureSkipVerify: true },
          metricRelabelings: [{
            action: 'drop',
            sourceLabels: ['__name__'],
            regex: 'scheduler_(e2e_scheduling_latency_microseconds|scheduling_algorithm_predicate_evaluation|scheduling_algorithm_priority_evaluation|scheduling_algorithm_preemption_evaluation|scheduling_algorithm_latency_microseconds|binding_latency_microseconds|scheduling_latency_seconds)',
          },],
        }],
      },
    },

    serviceMonitorKubeControllerManager+: {
      spec+: {
        endpoints: [{
          port: 'https-metrics',
          interval: '1m',
          scheme: 'https',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          tlsConfig: { insecureSkipVerify: true },
          metricRelabelings: [{
            action: 'keep',
            sourceLabels: ['__name__'],
            regex: 'up',
          },],
        }],
      },
    },

    prometheusRule+: {
      metadata+: {
        name: 'prometheus-k8s-rules', # keep the name the same as that in previous versions of kubesphere
      },
    },
  },
}