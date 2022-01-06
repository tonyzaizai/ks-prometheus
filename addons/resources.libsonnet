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
    alertmanager+: {
      resources: {
        requests: {
          cpu: '20m',
          memory: '30Mi',
        },
        limits: {
          cpu: '200m',
          memory: '200Mi',
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