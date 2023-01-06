{
  _config+:: {
    kubeletSelector: 'job=~"kubelet|kubeedge"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    coreDNSSelector: 'job="coredns"',
    kubeApiserverSelector: 'job="apiserver"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    prometheusSelector: 'job="prometheus"',
    podLabel: 'pod',
    edgeSelector: 'job="kubeedge"',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'k8s.rules',
        rules: [
          {
            // Use irate instead of offset in the expression, but the record name remains the same.
            record: 'namespace:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum (irate(container_cpu_usage_seconds_total{%(kubeletSelector)s, image!="", container!=""}[5m]) * on(namespace, %(clusterLabel)s) group_left(workspace) kube_namespace_labels{%(kubeStateMetricsSelector)s}) by (namespace, workspace, %(clusterLabel)s)
              or on(namespace, workspace, %(clusterLabel)s) max by(namespace, workspace, %(clusterLabel)s) (kube_namespace_labels * 0)
            ||| % $._config,
          },
          {
            record: 'namespace:container_memory_usage_bytes:sum',
            expr: |||
              sum(container_memory_usage_bytes{%(kubeletSelector)s, image!="", container!=""} * on(namespace, %(clusterLabel)s) group_left(workspace) kube_namespace_labels{%(kubeStateMetricsSelector)s}) by (namespace, workspace, %(clusterLabel)s)
              or on(namespace, workspace, %(clusterLabel)s) max by(namespace, workspace, %(clusterLabel)s) (kube_namespace_labels * 0)
            ||| % $._config,
          },
          {
            record: 'namespace:container_memory_usage_bytes_wo_cache:sum',
            expr: |||
              sum(container_memory_working_set_bytes{%(kubeletSelector)s, image!="", container!=""} * on(namespace, %(clusterLabel)s) group_left(workspace) kube_namespace_labels{%(kubeStateMetricsSelector)s}) by (namespace, workspace, %(clusterLabel)s)
              or on(namespace, workspace, %(clusterLabel)s) max by(namespace, workspace, %(clusterLabel)s) (kube_namespace_labels * 0)
            ||| % $._config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (namespace, label_name, %(clusterLabel)s) (
                  sum(kube_pod_container_resource_requests{resource="memory", %(kubeStateMetricsSelector)s} * on (endpoint, instance, job, namespace, pod, service, %(clusterLabel)s) group_left(phase) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)) by (namespace, pod, %(clusterLabel)s)
                * on (namespace, pod, %(clusterLabel)s)
                  group_left(label_name) kube_pod_labels{%(kubeStateMetricsSelector)s}
              )
            ||| % $._config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (namespace, label_name, %(clusterLabel)s) (
                  sum(kube_pod_container_resource_requests{resource="cpu", %(kubeStateMetricsSelector)s} * on (endpoint, instance, job, namespace, pod, service, %(clusterLabel)s) group_left(phase) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)) by (namespace, pod, %(clusterLabel)s)
                * on (namespace, pod, %(clusterLabel)s)
                  group_left(label_name) kube_pod_labels{%(kubeStateMetricsSelector)s}
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'node.rules',
        rules: [
          {
            // cpu used: all cpu cycle - cpu idle 
            record: 'node_cpu_used_seconds_total',
            expr: |||
              sum (node_cpu_seconds_total{%(nodeExporterSelector)s, mode=~"user|nice|system|iowait|irq|softirq"}) by (cpu, instance, job, namespace, pod, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            // This rule results in the tuples (namespace,pod,node,owner_name,owner_kind,qos) => 1;
            // It is used to associate the owner, qos, and other relationships of the Pod.
            record: 'qos_owner_node:kube_pod_info:',
            expr: |||
              max by (namespace,pod,node,owner_name,owner_kind,qos, %(clusterLabel)s)(kube_pod_info{%(kubeStateMetricsSelector)s}
                * on (namespace, pod, %(clusterLabel)s) group_left(owner_kind, owner_name) kube_pod_owner{%(kubeStateMetricsSelector)s}
                * on (namespace,pod, %(clusterLabel)s) group_left(qos) max by (namespace,pod,qos, %(clusterLabel)s)
                  ((label_replace(container_memory_working_set_bytes{%(kubeletSelector)s, container="",pod!="",id=~".*(burstable|besteffort).*"},"qos","$1","id",".*(burstable|besteffort).*")
                  or label_replace(container_memory_working_set_bytes{%(kubeletSelector)s, container="",pod!="",id!~".*(burstable|besteffort).*"},"qos","guaranteed","id",".*")) > bool 0))
            ||| % $._config,
          },
          {
            // This rule results in the tuples (node, namespace, instance) => 1;
            // it is used to calculate per-node metrics, given namespace & instance.
            record: 'node_namespace_pod:kube_pod_info:',
            expr: |||
              max(kube_pod_info{%(kubeStateMetricsSelector)s} * on(node, %(clusterLabel)s) group_left(role) kube_node_role{%(kubeStateMetricsSelector)s, role="master"} or on(%(podLabel)s, namespace, %(clusterLabel)s) kube_pod_info{%(kubeStateMetricsSelector)s}) by (node, namespace, host_ip, role, %(podLabel)s, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            // This rule gives the number of CPUs per node.
            record: 'node:node_num_cpu:sum',
            expr: |||
              count by (node, host_ip, role, %(clusterLabel)s) (sum by (node, cpu, host_ip, role, %(clusterLabel)s) (
                node_cpu_seconds_total{%(nodeExporterSelector)s}
              * on (namespace, %(podLabel)s, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              ))
            ||| % $._config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: ':node_cpu_utilisation:avg1m',
            expr: |||
              avg by(%(clusterLabel)s) (irate(node_cpu_used_seconds_total{%(nodeExporterSelector)s}[5m]))
            ||| % $._config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: 'node:node_cpu_utilisation:avg1m',
            expr: |||
              avg by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_cpu_used_seconds_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, %(podLabel)s, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:)
            ||| % $._config,
          },
          {
            record: ':node_memory_utilisation:',
            expr: |||
              1 -
              sum by(%(clusterLabel)s) (node_memory_MemFree_bytes{%(nodeExporterSelector)s} + node_memory_Cached_bytes{%(nodeExporterSelector)s} + node_memory_Buffers_bytes{%(nodeExporterSelector)s} + node_memory_SReclaimable_bytes{%(nodeExporterSelector)s})
              /
              sum by(%(clusterLabel)s) (node_memory_MemTotal_bytes{%(nodeExporterSelector)s})
            ||| % $._config,
          },
          {
            // Available memory per node
            // SINCE 2018-02-08
            record: 'node:node_memory_bytes_available:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                (node_memory_MemFree_bytes{%(nodeExporterSelector)s} + node_memory_Cached_bytes{%(nodeExporterSelector)s} + node_memory_Buffers_bytes{%(nodeExporterSelector)s} + node_memory_SReclaimable_bytes{%(nodeExporterSelector)s})
                * on (namespace, %(podLabel)s, %(clusterLabel)s) group_left(node, host_ip, role)
                  node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // Total memory per node
            // SINCE 2018-02-08
            record: 'node:node_memory_bytes_total:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                node_memory_MemTotal_bytes{%(nodeExporterSelector)s}
                * on (namespace, %(podLabel)s, %(clusterLabel)s) group_left(node, host_ip, role)
                  node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // DEPENDS 2018-02-08
            // REPLACE node:node_memory_utilisation:
            record: 'node:node_memory_utilisation:',
            expr: |||
              1 - (node:node_memory_bytes_available:sum / node:node_memory_bytes_total:sum)
            ||| % $._config,
          },
          {
            record: 'node:data_volume_iops_reads:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_disk_reads_completed_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:data_volume_iops_writes:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_disk_writes_completed_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:data_volume_throughput_bytes_read:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_disk_read_bytes_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:data_volume_throughput_bytes_written:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_disk_written_bytes_total{%(nodeExporterSelector)s}[5m])
              * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: ':node_net_utilisation:sum_irate',
            expr: |||
              sum by(%(clusterLabel)s) (irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])) +
              sum by(%(clusterLabel)s) (irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'node:node_net_utilisation:sum_irate',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                (irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m]) +
                irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m]))
              * on (namespace, %(podLabel)s, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_net_bytes_transmitted:sum_irate',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_network_transmit_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_net_bytes_received:sum_irate',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (
                irate(node_network_receive_bytes_total{%(nodeExporterSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role)
                node_namespace_pod:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: 'node:node_inodes_total:',
            expr: |||
              sum by(node, host_ip, role, %(clusterLabel)s) (sum(max(node_filesystem_files{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s}) by (device, pod, namespace, %(clusterLabel)s)) by (pod, namespace, %(clusterLabel)s) * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:)
            ||| % $._config,
          },
          {
            record: 'node:node_inodes_free:',
            expr: |||
              sum by(node, host_ip, role, %(clusterLabel)s) (sum(max(node_filesystem_files_free{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s}) by (device, pod, namespace, %(clusterLabel)s)) by (pod, namespace, %(clusterLabel)s) * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:)
            ||| % $._config,
          },
          {
            record: 'node:load1:ratio',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (node_load1{%(nodeExporterSelector)s} * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:) / node:node_num_cpu:sum
            ||| % $._config,
          },
          {
            record: 'node:load5:ratio',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (node_load5{%(nodeExporterSelector)s} * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:) / node:node_num_cpu:sum
            ||| % $._config,
          },
          {
            record: 'node:load15:ratio',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) (node_load15{%(nodeExporterSelector)s} * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:) / node:node_num_cpu:sum
            ||| % $._config,
          },
          {
            record: 'node:pod_count:sum',
            expr: |||
              sum by (node, host_ip, role, %(clusterLabel)s) ((kube_pod_status_scheduled{%(kubeStateMetricsSelector)s, condition="true"} > 0)  * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:)
            ||| % $._config,
          },
          {
            record: 'node:pod_capacity:sum',
            expr: |||
              (sum(kube_node_status_capacity{resource="pods", %(kubeStateMetricsSelector)s}) by (node, %(clusterLabel)s) * on(node, %(clusterLabel)s) group_left(host_ip, role) max by(node, host_ip, role, %(clusterLabel)s) (node_namespace_pod:kube_pod_info:{node!="",host_ip!=""}))
            ||| % $._config,
          },
          {
            record: 'node:pod_utilization:ratio',
            expr: |||
              node:pod_running:count / node:pod_capacity:sum
            ||| % $._config,
          },
          {
            record: 'node:pod_running:count',
            expr: |||
              count(node_namespace_pod:kube_pod_info: unless on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase=~"Failed|Pending|Unknown|Succeeded"} > 0)) by (node, host_ip, role, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:pod_succeeded:count',
            expr: |||
              count(node_namespace_pod:kube_pod_info: unless on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase=~"Failed|Pending|Unknown|Running"} > 0)) by (node, host_ip, role, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:pod_abnormal:count',
            expr: |||
              count(node_namespace_pod:kube_pod_info:{node!="",host_ip!=""} unless on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase="Succeeded"}>0) unless on (pod, namespace, %(clusterLabel)s) ((kube_pod_status_ready{%(kubeStateMetricsSelector)s, condition="true"}>0) and on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase="Running"}>0)) unless on (pod, namespace, %(clusterLabel)s) kube_pod_container_status_waiting_reason{%(kubeStateMetricsSelector)s, reason="ContainerCreating"}>0) by (node, host_ip, role, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:pod_abnormal:ratio',
            expr: |||
              node:pod_abnormal:count / count(node_namespace_pod:kube_pod_info:{node!="",host_ip!=""} unless on (pod, namespace, %(clusterLabel)s) kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase="Succeeded"}>0) by (node, host_ip, role, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:disk_space_available:',
            expr: |||
              sum(max(node_filesystem_avail_bytes{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s} * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:) by (device, node, host_ip, role, %(clusterLabel)s)) by (node, host_ip, role, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:disk_space_utilization:ratio',
            expr: |||
              1- sum(max(node_filesystem_avail_bytes{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s} * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:) by (device, node, host_ip, role, %(clusterLabel)s)) by (node, host_ip, role, %(clusterLabel)s) / sum(max(node_filesystem_size_bytes{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s} * on (namespace, pod, %(clusterLabel)s) group_left(node, host_ip, role) node_namespace_pod:kube_pod_info:) by (device, node, host_ip, role, %(clusterLabel)s)) by (node, host_ip, role, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:disk_inode_utilization:ratio',
            expr: |||
              (1 - (node:node_inodes_free: / node:node_inodes_total:))
            ||| % $._config,
          },
          {
            record: 'edge_node_cpu_used_seconds_total',
            expr: |||
              sum (node_cpu_seconds_total{%(edgeSelector)s, mode=~"user|nice|system|iowait|irq|softirq"}) by (cpu, node, job, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'node:edge_node_cpu_utilisation:avg1m',
            expr: |||
              avg by (node, %(clusterLabel)s) (
                irate(edge_node_cpu_used_seconds_total{%(edgeSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'node:edge_node_num_cpu:sum',
            expr: |||
              count by (node, %(clusterLabel)s) (sum by (node, cpu, %(clusterLabel)s) (
                node_cpu_seconds_total{%(edgeSelector)s}
              ))
            ||| % $._config,
          },
          {
            record: 'node:edge_node_memory_bytes_available:sum',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                (node_memory_MemFree_bytes{%(edgeSelector)s} + node_memory_Cached_bytes{%(edgeSelector)s} + node_memory_Buffers_bytes{%(edgeSelector)s} + node_memory_SReclaimable_bytes{%(edgeSelector)s})
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_node_memory_bytes_total:sum',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                node_memory_MemTotal_bytes{%(edgeSelector)s}
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_node_memory_utilisation:',
            expr: |||
              1 - (node:edge_node_memory_bytes_available:sum / node:edge_node_memory_bytes_total:sum)
            ||| % $._config,
          },
          {
            record: 'node:edge_node_net_utilisation:sum_irate',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                (irate(node_network_receive_bytes_total{%(edgeSelector)s,%(hostNetworkInterfaceSelector)s}[5m]) +
                irate(node_network_transmit_bytes_total{%(edgeSelector)s,%(hostNetworkInterfaceSelector)s}[5m]))
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_node_net_bytes_transmitted:sum_irate',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                irate(node_network_transmit_bytes_total{%(edgeSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_node_net_bytes_received:sum_irate',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                irate(node_network_receive_bytes_total{%(edgeSelector)s,%(hostNetworkInterfaceSelector)s}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_data_volume_iops_reads:sum',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                irate(node_disk_reads_completed_total{%(edgeSelector)s}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_data_volume_iops_writes:sum',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                irate(node_disk_writes_completed_total{%(edgeSelector)s}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_data_volume_throughput_bytes_read:sum',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                irate(node_disk_read_bytes_total{%(edgeSelector)s}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_data_volume_throughput_bytes_written:sum',
            expr: |||
              sum by (node, %(clusterLabel)s) (
                irate(node_disk_written_bytes_total{%(edgeSelector)s}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'node:edge_load1:ratio',
            expr: |||
              sum by (node, %(clusterLabel)s) (node_load1{%(edgeSelector)s}) / node:edge_node_num_cpu:sum
            ||| % $._config,
          },
          {
            record: 'node:edge_load5:ratio',
            expr: |||
              sum by (node, %(clusterLabel)s) (node_load5{%(edgeSelector)s}) / node:edge_node_num_cpu:sum
            ||| % $._config,
          },
          {
            record: 'node:edge_load15:ratio',
            expr: |||
              sum by (node, %(clusterLabel)s) (node_load15{%(edgeSelector)s}) / node:edge_node_num_cpu:sum
            ||| % $._config,
          },
        ],
      },
      {
        name: 'cluster.rules',
        rules: [
          {
            record: 'cluster:pod_abnormal:sum',
            expr: |||
              count by(%(clusterLabel)s) (kube_pod_info{%(kubeStateMetricsSelector)s} unless on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase="Succeeded"}>0) unless on (pod, namespace, %(clusterLabel)s) ((kube_pod_status_ready{%(kubeStateMetricsSelector)s, condition="true"}>0) and on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase="Running"}>0)) unless on (pod, namespace, %(clusterLabel)s) kube_pod_container_status_waiting_reason{%(kubeStateMetricsSelector)s, reason="ContainerCreating"}>0)
            ||| % $._config,
          },
          {
            record: 'cluster:pod:sum',
            expr: |||
              sum by(%(clusterLabel)s) ((kube_pod_status_scheduled{%(kubeStateMetricsSelector)s, condition="true"} > 0)  * on (namespace, pod, %(clusterLabel)s) group_left(node) (sum by (node, namespace, pod, %(clusterLabel)s) (kube_pod_info)))
            ||| % $._config,
          },
          {
            record: 'cluster:pod_abnormal:ratio',
            expr: |||
              cluster:pod_abnormal:sum / sum by(%(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase!="Succeeded"})
            ||| % $._config,
          },
          {
            record: 'cluster:pod_running:count',
            expr: |||
              count by(%(clusterLabel)s) (kube_pod_info{%(kubeStateMetricsSelector)s} and on (pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase="Running"}>0))
            ||| % $._config,
          },
          {
            record: 'cluster:pod_utilization:ratio',
            expr: |||
              cluster:pod_running:count / sum by(%(clusterLabel)s) (kube_node_status_capacity{resource="pods", %(kubeStateMetricsSelector)s})
            ||| % $._config,
          },
          {
            record: 'cluster:disk_utilization:ratio',
            expr: |||
              1 - sum by(%(clusterLabel)s) (max(node_filesystem_avail_bytes{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s}) by (device, instance, %(clusterLabel)s)) / sum by(%(clusterLabel)s) (max(node_filesystem_size_bytes{device=~"/dev/.*", device!~"/dev/loop\\d+", %(nodeExporterSelector)s}) by (device, instance, %(clusterLabel)s))
            ||| % $._config,
          },
          {
            record: 'cluster:disk_inode_utilization:ratio',
            expr: |||
              1 - sum by(%(clusterLabel)s) (node:node_inodes_free:) / sum by(%(clusterLabel)s) (node:node_inodes_total:)
            ||| % $._config,
          },
          {
            record: 'cluster:node_offline:sum',
            expr: |||
              sum by(%(clusterLabel)s) (kube_node_status_condition{%(kubeStateMetricsSelector)s, condition="Ready", status=~"unknown|false"})
            ||| % $._config,
          },
          {
            record: 'cluster:node_offline:ratio',
            expr: |||
              sum by(%(clusterLabel)s) (kube_node_status_condition{%(kubeStateMetricsSelector)s, condition="Ready", status=~"unknown|false"}) / sum by(%(clusterLabel)s) (kube_node_status_condition{%(kubeStateMetricsSelector)s, condition="Ready"})
            ||| % $._config,
          },
        ],
      },
      {
        name: 'namespace.rules',
        rules: [
          {
            record: 'namespace:pod_abnormal:count',
            expr: |||
              (count by(namespace, %(clusterLabel)s) (kube_pod_info{%(kubeStateMetricsSelector)s} unless on(pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s,phase="Succeeded"} > 0) unless on(pod, namespace, %(clusterLabel)s) ((kube_pod_status_ready{condition="true",%(kubeStateMetricsSelector)s} > 0) and on(pod, namespace, %(clusterLabel)s) (kube_pod_status_phase{%(kubeStateMetricsSelector)s,phase="Running"} > 0)) unless on(pod, namespace, %(clusterLabel)s) kube_pod_container_status_waiting_reason{%(kubeStateMetricsSelector)s,reason="ContainerCreating"} > 0) or on(namespace, %(clusterLabel)s) (group by(namespace, %(clusterLabel)s) (kube_pod_info{%(kubeStateMetricsSelector)s}) * 0)) * on(namespace, %(clusterLabel)s) group_left(workspace) (kube_namespace_labels{%(kubeStateMetricsSelector)s}) > 0
            ||| % $._config,
          },
          {
            record: 'namespace:pod_abnormal:ratio',
            expr: |||
              namespace:pod_abnormal:count / (sum(kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase!="Succeeded", namespace!=""}) by (namespace, %(clusterLabel)s) * on (namespace, %(clusterLabel)s) group_left(workspace)(kube_namespace_labels{%(kubeStateMetricsSelector)s}))
            ||| % $._config,
          },
          {
            record: 'namespace:resourcequota_used:ratio',
            expr: |||
              max(kube_resourcequota{%(kubeStateMetricsSelector)s, type="used"}) by (resource, namespace, %(clusterLabel)s) / min(kube_resourcequota{%(kubeStateMetricsSelector)s, type="hard"}) by (resource, namespace, %(clusterLabel)s) *  on (namespace, %(clusterLabel)s) group_left(workspace) (kube_namespace_labels{%(kubeStateMetricsSelector)s})
            ||| % $._config,
          },
          {
            record: 'namespace:workload_cpu_usage:sum',
            expr: |||
              sum (label_replace(label_join(sum(irate(container_cpu_usage_seconds_total{%(kubeletSelector)s, pod!="", image!=""}[5m])) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:workload_memory_usage:sum',
            expr: |||
              sum (label_replace(label_join(sum(container_memory_usage_bytes{%(kubeletSelector)s, pod!="", image!=""}) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:workload_memory_usage_wo_cache:sum',
            expr: |||
              sum (label_replace(label_join(sum(container_memory_working_set_bytes{%(kubeletSelector)s, pod!="", image!=""}) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:workload_net_bytes_transmitted:sum_irate',
            expr: |||
              sum (label_replace(label_join(sum(irate(container_network_transmit_bytes_total{pod!="", interface!~"^(cali.+|tunl.+|dummy.+|kube.+|flannel.+|cni.+|docker.+|veth.+|lo.*)", %(kubeletSelector)s}[5m])) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:workload_net_bytes_transmitted:sum',
            expr: |||
              sum (label_replace(label_join(sum(container_network_transmit_bytes_total{pod!="", interface!~"^(cali.+|tunl.+|dummy.+|kube.+|flannel.+|cni.+|docker.+|veth.+|lo.*)", %(kubeletSelector)s}) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:workload_net_bytes_received:sum_irate',
            expr: |||
              sum (label_replace(label_join(sum(irate(container_network_receive_bytes_total{pod!="", interface!~"^(cali.+|tunl.+|dummy.+|kube.+|flannel.+|cni.+|docker.+|veth.+|lo.*)", %(kubeletSelector)s}[5m])) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:workload_net_bytes_received:sum',
            expr: |||
              sum (label_replace(label_join(sum(container_network_receive_bytes_total{pod!="", interface!~"^(cali.+|tunl.+|dummy.+|kube.+|flannel.+|cni.+|docker.+|veth.+|lo.*)", %(kubeletSelector)s}) by (namespace, pod, %(clusterLabel)s) * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind", "Deployment", "owner_kind", "ReplicaSet"), "owner_kind", "Pod", "owner_kind", "<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"), "workload",":","owner_kind","owner_name"), "workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, owner_kind, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'namespace:deployment_unavailable_replicas:ratio',
            expr: |||
              label_replace(label_replace(sum(kube_deployment_status_replicas_unavailable{%(kubeStateMetricsSelector)s}) by (deployment, namespace, %(clusterLabel)s) / sum(kube_deployment_spec_replicas{%(kubeStateMetricsSelector)s}) by (deployment, namespace, %(clusterLabel)s) * on (namespace, %(clusterLabel)s) group_left(workspace)(kube_namespace_labels{%(kubeStateMetricsSelector)s}), "workload","Deployment:$1", "deployment", "(.*)"), "owner_kind","Deployment", "", "")
            ||| % $._config,
          },
          {
            record: 'namespace:daemonset_unavailable_replicas:ratio',
            expr: |||
              label_replace(label_replace(sum(kube_daemonset_status_number_unavailable{%(kubeStateMetricsSelector)s}) by (daemonset, namespace, %(clusterLabel)s) / sum(kube_daemonset_status_desired_number_scheduled{%(kubeStateMetricsSelector)s}) by (daemonset, namespace, %(clusterLabel)s) * on (namespace, %(clusterLabel)s) group_left(workspace)(kube_namespace_labels{%(kubeStateMetricsSelector)s}) , "workload","DaemonSet:$1", "daemonset", "(.*)"), "owner_kind","DaemonSet", "", "")
            ||| % $._config,
          },
          {
            record: 'namespace:statefulset_unavailable_replicas:ratio',
            expr: |||
              label_replace(label_replace((1 - sum(kube_statefulset_status_replicas_current{%(kubeStateMetricsSelector)s}) by (statefulset, namespace, %(clusterLabel)s) / sum(kube_statefulset_replicas{%(kubeStateMetricsSelector)s}) by (statefulset, namespace, %(clusterLabel)s)) * on (namespace, %(clusterLabel)s) group_left(workspace)(kube_namespace_labels{%(kubeStateMetricsSelector)s}) , "workload","StatefulSet:$1", "statefulset", "(.*)"), "owner_kind","StatefulSet", "", "")
            ||| % $._config,
          },
          {
            record: 'namespace:kube_pod_resource_request:sum',
            expr: |||
              sum(kube_pod_container_resource_requests * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name) label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind","Deployment","owner_kind","ReplicaSet"),"owner_kind","Pod","owner_kind","<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)")) by (namespace, owner_kind, pod, resource, %(clusterLabel)s)* on(namespace, %(clusterLabel)s) group_left(workspace)kube_namespace_labels{%(kubeStateMetricsSelector)s}
            ||| % $._config,
          },
          {
            record: 'namespace:kube_workload_resource_request:sum',
            expr: |||
              sum(label_replace(label_join(kube_pod_container_resource_requests * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name)label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind","Deployment","owner_kind","ReplicaSet"),"owner_kind","Pod","owner_kind","<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"),"workload",":","owner_kind","owner_name"),"workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, resource, %(clusterLabel)s)* on(namespace, %(clusterLabel)s) group_left(workspace) kube_namespace_labels{%(kubeStateMetricsSelector)s}
            ||| % $._config,
          },
          {
            record: 'namespace:pvc_bytes_total:sum',
            expr: |||
              sum(label_replace(label_join(kube_pod_spec_volumes_persistentvolumeclaims_info * on (pod, namespace, %(clusterLabel)s) group_left(owner_kind,owner_name)label_replace(label_join(label_replace(label_replace(kube_pod_owner{%(kubeStateMetricsSelector)s},"owner_kind","Deployment","owner_kind","ReplicaSet"),"owner_kind","Pod","owner_kind","<none>"),"tmp",":","owner_name","pod"),"owner_name","$1","tmp","<none>:(.*)"),"workload",":","owner_kind","owner_name"),"workload","$1","workload","(Deployment:.+)-(.+)")) by (namespace, workload, pod, persistentvolumeclaim, %(clusterLabel)s)* on(namespace, pod, %(clusterLabel)s) group_left(node) kube_pod_info{job="kube-state-metrics"}* on (node, persistentvolumeclaim, namespace, %(clusterLabel)s) group_left kubelet_volume_stats_capacity_bytes * on(namespace, %(clusterLabel)s) group_left(workspace) kube_namespace_labels{%(kubeStateMetricsSelector)s}
            ||| % $._config,
          },
        ],
      },
      {
        name: 'apiserver.rules',
        rules: [
          {
            record: 'apiserver:up:sum',
            expr: |||
              sum by(%(clusterLabel)s) (up{%(kubeApiserverSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_total:sum_irate',
            expr: |||
              sum by(%(clusterLabel)s) (irate(apiserver_request_total{%(kubeApiserverSelector)s}[5m]))
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_total:sum_verb_irate',
            expr: |||
              sum(irate(apiserver_request_total{%(kubeApiserverSelector)s}[5m])) by (verb, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_duration:avg',
            expr: |||
              sum by(%(clusterLabel)s) (irate(apiserver_request_duration_seconds_sum{%(kubeApiserverSelector)s,subresource!="log", verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m])) / sum by(%(clusterLabel)s) (irate(apiserver_request_duration_seconds_count{%(kubeApiserverSelector)s, subresource!="log",verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m]))
            ||| % $._config,
          },
          {
            record: 'apiserver:apiserver_request_duration:avg_by_verb',
            expr: |||
              sum(irate(apiserver_request_duration_seconds_sum{%(kubeApiserverSelector)s,subresource!="log", verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m])) by (verb, %(clusterLabel)s) / sum(irate(apiserver_request_duration_seconds_count{%(kubeApiserverSelector)s, subresource!="log",verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m])) by (verb, %(clusterLabel)s)
            ||| % $._config,
          },
        ],
      },
      {
        name: 'scheduler.rules',
        rules: [
          {
            record: 'scheduler:up:sum',
            expr: |||
              sum by(%(clusterLabel)s) (up{%(kubeSchedulerSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'scheduler:scheduler_schedule_attempts:sum',
            expr: |||
              sum(scheduler_schedule_attempts_total{%(kubeSchedulerSelector)s}) by (result, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'scheduler:scheduler_schedule_attempts:sum_rate',
            expr: |||
              sum(rate(scheduler_schedule_attempts_total{%(kubeSchedulerSelector)s}[5m])) by (result, %(clusterLabel)s)
            ||| % $._config,
          },
          {
            record: 'scheduler:scheduler_e2e_scheduling_duration:avg',
            expr: |||
              (sum by(%(clusterLabel)s) (rate(scheduler_e2e_scheduling_duration_seconds_sum{%(kubeSchedulerSelector)s}[1h]))  / sum by(%(clusterLabel)s) (rate(scheduler_e2e_scheduling_duration_seconds_count{%(kubeSchedulerSelector)s}[1h])))
            ||| % $._config,
          },
        ],
      },
      {
        name: 'scheduler_histogram.rules',
        rules: [
          {
            record: 'scheduler:%s:histogram_quantile' % metric,
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(%(metric)s_seconds_bucket{%(kubeSchedulerSelector)s}[1h])) by (le, %(clusterLabel)s) )
            ||| % ({ quantile: quantile, metric: metric } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
          for metric in ['scheduler_e2e_scheduling_duration']
        ],
      },
      {
        name: 'controller_manager.rules',
        rules: [
          {
            record: 'controller_manager:up:sum',
            expr: |||
              sum by(%(clusterLabel)s) (up{%(kubeControllerManagerSelector)s} == 1)
            ||| % $._config,
          },
        ],
      },
      {
        name: 'coredns.rules',
        rules: [
          {
            record: 'coredns:up:sum',
            expr: |||
              sum by(%(clusterLabel)s) (up{%(kubeCoreDNSSelector)s} == 1)
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
