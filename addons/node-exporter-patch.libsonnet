{
  nodeExporter+: {
    local mixinConfig = super._config.mixin._config,
    mixin:: (import './node-exporter-mixin/mixin.libsonnet') + {
      _config+:: mixinConfig,
    },

    serviceMonitor+: {
      spec+: {
        endpoints: [{
          port: 'https',
          scheme: 'https',
          interval: '15s',
          bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          relabelings: [
            {
              action: 'replace',
              regex: '(.*)',
              replacement: '$1',
              sourceLabels: ['__meta_kubernetes_pod_node_name'],
              targetLabel: 'instance',
            },
            {
              action: 'labeldrop',
              regex: '(service|endpoint)',
            },
          ],
          tlsConfig: {
            insecureSkipVerify: true,
          },
          metricRelabelings+: [{
            action: 'keep',
            sourceLabels: ['__name__'],
            regex: std.join('|', [
              'node_(uname|network)_info',
              'node_cpu_.+',
              'node_memory_Mem.+_bytes',
              'node_memory_SReclaimable_bytes',
              'node_memory_Cached_bytes',
              'node_memory_Buffers_bytes',
              'node_network_(.+_bytes_total|up)',
              'node_network_.+_errs_total',
              'node_nf_conntrack_entries.*',
              'node_disk_.+_completed_total',
              'node_disk_.+_bytes_total',
              'node_filesystem_files',
              'node_filesystem_files_free',
              'node_filesystem_avail_bytes',
              'node_filesystem_size_bytes',
              'node_filesystem_free_bytes',
              'node_filesystem_readonly',
              'node_load.+',
              'node_timex_offset_seconds',
            ]),
          }],
        },],
      },
    },
  },
}