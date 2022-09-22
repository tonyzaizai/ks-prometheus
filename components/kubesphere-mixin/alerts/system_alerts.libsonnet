local utils = import 'kubernetes-mixin/lib/utils.libsonnet';

{
  _config+:: {
    ksControllerManagerSelector: error 'must provide selector for ks-controller-manager',

    kubeConfigCertExpirationWarningSeconds: 7 * 24 * 3600,
    kubeConfigCertExpirationCriticalSeconds: 1 * 24 * 3600,
    kubeSphereLicenseExpirationWarningSeconds: 7 * 24 * 3600,
    kubeSphereLicenseExpirationCriticalSeconds: 1 * 24 * 3600,
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubesphere-system',
        rules: [
          {
            alert: 'KubeConfigCertificateExpiration',
            expr: |||
              kubesphere_enterprise_cluster_certificate_validity_seconds{%(ksControllerManagerSelector)s} <  %(kubeConfigCertExpirationWarningSeconds)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $labels.cluster }} cluster kubeconfig certificate is expiring in less than %s.' % (utils.humanizeSeconds($._config.kubeConfigCertExpirationWarningSeconds)),
              summary: 'kubeconfig certificate is about to expire.',
            },
          },
          {
            alert: 'KubeConfigCertificateExpiration',
            expr: |||
              kubesphere_enterprise_cluster_certificate_validity_seconds{%(ksControllerManagerSelector)s} <  %(kubeConfigCertExpirationCriticalSeconds)s
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: '{{ $labels.cluster }} cluster kubeconfig certificate is expiring in less than %s.' % (utils.humanizeSeconds($._config.kubeConfigCertExpirationCriticalSeconds)),
              summary: 'kubeconfig certificate is about to expire.',
            },
          },
          {
            alert: 'KubeSphereLicenseExpiration',
            expr: |||
              kubesphere_enterprise_license_validity_seconds{%(ksControllerManagerSelector)s} <  %(kubeSphereLicenseExpirationWarningSeconds)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'KubeSphere license is expiring in less than %s.' % (utils.humanizeSeconds($._config.kubeSphereLicenseExpirationWarningSeconds)),
              summary: 'KubeSphere license is about to expire.',
            },
          },
          {
            alert: 'KubeSphereLicenseExpiration',
            expr: |||
              kubesphere_enterprise_license_validity_seconds{%(ksControllerManagerSelector)s} <  %(kubeSphereLicenseExpirationCriticalSeconds)s
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'KubeSphere license is expiring in less than %s.' % (utils.humanizeSeconds($._config.kubeSphereLicenseExpirationCriticalSeconds)),
              summary: 'KubeSphere license is about to expire.',
            },
          },
        ],
      },
    ],
  },
}
