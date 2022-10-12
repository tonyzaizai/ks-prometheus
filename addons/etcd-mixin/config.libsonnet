 {
    _config+:: (import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet')._config + {
        // kubeClusterLabel is used to identify a kubernetes cluster.
        kubeClusterLabel: 'cluster',
    },    
}