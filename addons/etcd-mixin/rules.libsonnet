{
  _config+:: {
    etcd_selector: 'job=~".*etcd.*"',
    etcd_instance_labels: 'instance',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'etcd.rules',
        rules: [
          {
            expr: |||
              sum by(%(kubeClusterLabel)s) (up{%(etcd_selector)s} == 1)
            ||| % {etcd_selector: $._config.etcd_selector, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:up:sum',
          },
          {
            expr: |||
              sum(label_replace(sum(changes(etcd_server_leader_changes_seen_total{%(etcd_selector)s}[1h])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_server_leader_changes_seen:sum_changes',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_server_proposals_failed_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_server_proposals_failed:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_server_proposals_applied_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_server_proposals_applied:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_server_proposals_committed_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_server_proposals_committed:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(etcd_server_proposals_pending{%(etcd_selector)s}) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_server_proposals_pending:sum',
          },
          {
            expr: |||
              sum(label_replace(etcd_mvcc_db_total_size_in_bytes{%(etcd_selector)s},"node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_mvcc_db_total_size:sum',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_network_client_grpc_received_bytes_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_network_client_grpc_received_bytes:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_network_client_grpc_sent_bytes_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_network_client_grpc_sent_bytes:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(grpc_server_started_total{%(etcd_selector)s,grpc_type="unary"}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:grpc_server_started:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(grpc_server_handled_total{%(etcd_selector)s,grpc_type="unary",grpc_code!="OK"}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:grpc_server_handled:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(grpc_server_msg_received_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:grpc_server_msg_received:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(grpc_server_msg_sent_total{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:grpc_server_msg_sent:sum_irate',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_disk_wal_fsync_duration_seconds_sum{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s) / sum(irate(etcd_disk_wal_fsync_duration_seconds_count{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_disk_wal_fsync_duration:avg',
          },
          {
            expr: |||
              sum(label_replace(sum(irate(etcd_disk_backend_commit_duration_seconds_sum{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s) / sum(irate(etcd_disk_backend_commit_duration_seconds_count{%(etcd_selector)s}[5m])) by (%(etcd_instance_labels)s, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, %(kubeClusterLabel)s)
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            record: 'etcd:etcd_disk_backend_commit_duration:avg',
          },
        ],
      },
      {
        name: 'etcd_histogram.rules',
        rules: [
          {
            expr: |||
              histogram_quantile(0.99, sum(label_replace(sum(irate(etcd_disk_wal_fsync_duration_seconds_bucket{%(etcd_selector)s}[5m])) by (instance, le, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, le, %(kubeClusterLabel)s))
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            labels: {
              quantile: "0.99",
            },
            record: 'etcd:etcd_disk_wal_fsync_duration:histogram_quantile',
          },
          {
            expr: |||
              histogram_quantile(0.9, sum(label_replace(sum(irate(etcd_disk_wal_fsync_duration_seconds_bucket{%(etcd_selector)s}[5m])) by (instance, le, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, le, %(kubeClusterLabel)s))
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            labels: {
              quantile: "0.9",
            },
            record: 'etcd:etcd_disk_wal_fsync_duration:histogram_quantile',
          },
          {
            expr: |||
              histogram_quantile(0.5, sum(label_replace(sum(irate(etcd_disk_wal_fsync_duration_seconds_bucket{%(etcd_selector)s}[5m])) by (instance, le, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, le, %(kubeClusterLabel)s))
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            labels: {
              quantile: "0.5",
            },
            record: 'etcd:etcd_disk_wal_fsync_duration:histogram_quantile',
          },
          {
            expr: |||
              histogram_quantile(0.99, sum(label_replace(sum(irate(etcd_disk_backend_commit_duration_seconds_bucket{%(etcd_selector)s}[5m])) by (instance, le, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, le, %(kubeClusterLabel)s))
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            labels: {
              quantile: "0.99",
            },
            record: 'etcd:etcd_disk_backend_commit_duration:histogram_quantile',
          },
          {
            expr: |||
              histogram_quantile(0.9, sum(label_replace(sum(irate(etcd_disk_backend_commit_duration_seconds_bucket{%(etcd_selector)s}[5m])) by (instance, le, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, le, %(kubeClusterLabel)s))
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            labels: {
              quantile: "0.9",
            },
            record: 'etcd:etcd_disk_backend_commit_duration:histogram_quantile',
          },
          {
            expr: |||
              histogram_quantile(0.5, sum(label_replace(sum(irate(etcd_disk_backend_commit_duration_seconds_bucket{%(etcd_selector)s}[5m])) by (instance, le, %(kubeClusterLabel)s), "node", "$1", "%(etcd_instance_labels)s", "(.*):.*")) by (node, le, %(kubeClusterLabel)s))
            ||| % {etcd_selector: $._config.etcd_selector, etcd_instance_labels: $._config.etcd_instance_labels, kubeClusterLabel: $._config.kubeClusterLabel},
            labels: {
              quantile: "0.5",
            },
            record: 'etcd:etcd_disk_backend_commit_duration:histogram_quantile',
          },
        ],
      },
    ],
  }
}