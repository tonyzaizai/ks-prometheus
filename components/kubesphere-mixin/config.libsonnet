{
  _config+:: {
    ksApiserverSelector: 'job="ks-apiserver"',
    ksControllerManagerSelector: 'job="ks-controller-manager"',

    clusterLabel: 'cluster',
  },
}
