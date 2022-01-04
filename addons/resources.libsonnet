{
  values+:: {
    prometheus+: {
      resources: {
        requests: {
          cpu: '200m',
          memory: '400Mi',
        },
        limits: {
          cpu: '4',
          memory: '16Gi',
        },
      },
    },
    thanosRuler+: {
      resources: {
        requests: {
          cpu: '100m',
          memory: '200Mi',
        },
        limits: {
          cpu: '1',
          memory: '2Gi',
        },
      },
    },
  },
}