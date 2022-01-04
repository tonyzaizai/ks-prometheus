{
  _config+:: {
    prometheusSelector: 'job="prometheus"',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'prometheus.rules',
        rules: [
          {
            record: 'prometheus:up:sum',
            expr: |||
              sum(up{%(prometheusSelector)s} == 1)
            ||| % $._config,
          },
          {
            record: 'prometheus:prometheus_tsdb_head_samples_appended:sum_rate',
            expr: |||
              sum(rate(prometheus_tsdb_head_samples_appended_total{%(prometheusSelector)s} [5m])) by (job, pod)
            ||| % $._config,
          },
        ],
      },
    ],
  }
}