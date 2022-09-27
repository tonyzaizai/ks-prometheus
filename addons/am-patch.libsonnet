{
  values+:: {
    alertmanager+: {
      notificationManagerUrl:: 'http://notification-manager-svc.kubesphere-monitoring-system.svc:19093/api/v2/alerts',
      config+: {
        inhibit_rules: [
          {
            source_match: {
              severity: 'critical',
            },
            target_match_re: {
              severity: 'warning|info',
            },
            equal: ['namespace', 'alertname'],
          },
          {
            source_match: {
              severity: 'warning',
            },
            target_match_re: {
              severity: 'info',
            },
            equal: ['namespace', 'alertname'],
          },
        ],
        receivers: [
          {
            name: 'Default',
          },
          {
            name: 'Watchdog',
          },
          {
            name: 'prometheus',
            webhook_configs: [
              {
                url: $.values.alertmanager.notificationManagerUrl,
              },
            ]
          },
          {
            name: 'event',
            webhook_configs: [
              {
                url: $.values.alertmanager.notificationManagerUrl,
                send_resolved: false,
              },
            ]
          },
          {
            name: 'auditing',
            webhook_configs: [
              {
                url: $.values.alertmanager.notificationManagerUrl,
                send_resolved: false,
              },
            ],
          },
        ],
        route+: {
          group_by: ['namespace', 'alertname', 'rule_id'],
          routes: [
            {
              receiver: 'Watchdog',
              match: {
                alertname: 'Watchdog',
              },
            },
            {
              receiver: 'event',
              match: {
                alerttype: 'event',
              },
              group_interval: '30s',
            },
            {
              receiver: 'auditing',
              match: {
                alerttype: 'auditing',
              },
              group_interval: '30s',
            },
            {
              receiver: 'prometheus',
              match_re: {
                alerttype: '.*',
              },
            },
          ],
        },
      },
    },
  },
  alertmanager+: {
    mixin+:: {
      _config+:: {
        alertmanagerClusterLabels: 'cluster,namespace,service',
      },
    },
  },
}