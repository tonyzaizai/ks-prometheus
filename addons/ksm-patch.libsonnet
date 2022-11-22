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
                kube_(hpa|replicaset|replicationcontroller)_.+_generation,
                kube_clusterrole_info,
                kube_clusterrolebinding_info
              |||, 
              |||
                --custom-resource-state-config=spec:
                  resources:
                    - groupVersionKind:
                        group: iam.kubesphere.io
                        kind: "User"
                        version: "v1alpha2"
                      metricNamePrefix: ""
                      labelsFromPath:
                        user: [metadata, name]
                      metrics:
                        - name: "kubesphere_user_info"
                          help: "information about iam.kubesphere.io/user."
                          each:
                            type: Info
                            info: {}
              |||,
              '--resources=certificatesigningrequests,configmaps,cronjobs,daemonsets,deployments,endpoints,horizontalpodautoscalers,ingresses,jobs,leases,limitranges,mutatingwebhookconfigurations,namespaces,networkpolicies,nodes,persistentvolumeclaims,persistentvolumes,poddisruptionbudgets,pods,replicasets,replicationcontrollers,resourcequotas,secrets,services,statefulsets,storageclasses,validatingwebhookconfigurations,volumeattachments,clusterroles,clusterrolebindings,users',
              '--metric-annotations-allowlist=clusterroles=[kubesphere.io/creator]',
              '--metric-labels-allowlist=namespaces=[kubesphere.io/workspace]'],
              'kube-state-metrics',
              super.containers
            ),
          },
        },
      },
    },

    clusterRole+: {
      rules: [
      {
        apiGroups: [''],
        resources: [
          'configmaps',
          'secrets',
          'nodes',
          'pods',
          'services',
          'serviceaccounts',
          'resourcequotas',
          'replicationcontrollers',
          'limitranges',
          'persistentvolumeclaims',
          'persistentvolumes',
          'namespaces',
          'endpoints',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['apps'],
        resources: [
          'statefulsets',
          'daemonsets',
          'deployments',
          'replicasets',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['batch'],
        resources: [
          'cronjobs',
          'jobs',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['autoscaling'],
        resources: [
          'horizontalpodautoscalers',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['authentication.k8s.io'],
        resources: [
          'tokenreviews',
        ],
        verbs: ['create'],
      },
      {
        apiGroups: ['authorization.k8s.io'],
        resources: [
          'subjectaccessreviews',
        ],
        verbs: ['create'],
      },
      {
        apiGroups: ['policy'],
        resources: [
          'poddisruptionbudgets',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['certificates.k8s.io'],
        resources: [
          'certificatesigningrequests',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['storage.k8s.io'],
        resources: [
          'storageclasses',
          'volumeattachments',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['admissionregistration.k8s.io'],
        resources: [
          'mutatingwebhookconfigurations',
          'validatingwebhookconfigurations',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['networking.k8s.io'],
        resources: [
          'networkpolicies',
          'ingresses',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['coordination.k8s.io'],
        resources: [
          'leases',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['rbac.authorization.k8s.io'],
        resources: [
          'clusterrolebindings',
          'clusterroles',
          'rolebindings',
          'roles',
        ],
        verbs: ['list', 'watch'],
      },
      {
        apiGroups: ['iam.kubesphere.io'],
        resources: [
          'users',
        ],
        verbs: ['list', 'watch'],
      },
     ]
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
