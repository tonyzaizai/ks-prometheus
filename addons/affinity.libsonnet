(import 'kube-prometheus/addons/anti-affinity.libsonnet') + {
  values+:: {
    thanosRuler+: {
      podAntiAffinity: 'soft',
      podAntiAffinityTopologyKey: 'kubernetes.io/hostname',
    },

    prometheus+: {
      nodeAffinity: {
        preferredDuringSchedulingIgnoredDuringExecution: [{
          weight: 100,
          preference: {
            matchExpressions: [{key: 'node-role.kubernetes.io/monitoring', operator: 'Exists'}],
          },
        }],
      }
    },

    nodeExporter+: {
      nodeAffinity: {
        requiredDuringSchedulingIgnoredDuringExecution: {
          nodeSelectorTerms: [{
            matchExpressions: [{key: 'node-role.kubernetes.io/edge', operator: 'DoesNotExist'}],
          }],
        },
      },
    },
  },

  local antiaffinity=super.antiaffinity,
  thanosRuler+: {
    thanosRuler+: {
      spec+:
        antiaffinity(
          $.thanosRuler._config.selectorLabels,
          $.values.common.namespace,
          $.values.thanosRuler.podAntiAffinity,
          $.values.thanosRuler.podAntiAffinityTopologyKey,
        ),
    },
  },

  prometheus+: {
    prometheus+: {
      spec+: {
        affinity+: {
          nodeAffinity: $.values.prometheus.nodeAffinity,
        },
      },
    },
  },

  nodeExporter+: {
    daemonset+: {
      spec+: {
        template+: {
          spec+: {
            affinity+:{
              nodeAffinity: $.values.nodeExporter.nodeAffinity,
            },
          },
        },
      },
    },
  },
}