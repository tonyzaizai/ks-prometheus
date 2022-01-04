(import 'kube-prometheus/main.libsonnet') +
{ 
  values+:: {
    common+: {
      versions+: {thanos: error 'must provide version'} + (import './versions.json'),
      images+: {thanos: 'quay.io/thanos/thanos:v' + $.values.common.versions.thanos},
    },
    thanosRuler: {
      namespace: $.values.common.namespace,
      version: $.values.common.versions.thanos,
      image: $.values.common.images.thanos,
      name: 'k8s',
      mixin+: { ruleLabels: $.values.common.ruleLabels },
    },
  },
  thanosRuler: (import './components/thanos-ruler.libsonnet')($.values.thanosRuler),
}