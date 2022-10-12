(import 'alerts/alerts.libsonnet') + {
    _config+: {
        clusterLabel: 'cluster',
        nodeExporterSelector: 'job="node-exporter"',
        hostNetworkInterfaceSelector: 'device!~"veth.+"',
        runbookURLPattern: 'https://runbooks.prometheus-operator.dev/runbooks/general/%s',
    },
}