{
  values+:: {
    grafana+: {
      storage: { // will bind the grafana db to a persitent volume 
        className: '',
        size: '50Mi',
      },
    },
  },
  grafana+: {
    local _config = super._config,
    local grafanaDefConf = importstr '../tmp/grafana-sample.ini',

    config+: {
      stringData+: {
        [if !std.objectHas($.values.grafana, 'config') || 
          std.length($.values.grafana.config) == 0 then 'grafana.ini']: grafanaDefConf
      },
    },

    [if std.objectHas($.values.grafana, 'storage') && std.length($.values.grafana.storage) > 0 then 'storage']: {
      apiVersion: 'v1',
      kind: 'PersistentVolumeClaim',
      metadata: {
        name: 'grafana-storage',
        namespace: _config.namespace,
      },
      spec: {
        [if std.length($.values.grafana.storage.className) > 0 then 'storageClassName']: $.values.grafana.storage.className,
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: $.values.grafana.storage.size,
          },
        },
      }
    },

    deployment+: {
      spec+: {
        template+: {
          metadata+: {
            annotations+: {
              [if !std.objectHas($.values.grafana, 'config') || std.length($.values.grafana.config) == 0 then 'checksum/grafana-config']: std.md5(grafanaDefConf),
            },
          },
          spec+: {
            volumes: std.map(function(v) 
              if std.objectHas($.values.grafana, 'storage') && std.length($.values.grafana.storage) > 0 && v.name == 'grafana-storage' then {
                name: v.name, 
                persistentVolumeClaim: {claimName: 'grafana-storage'},
              } else v, 
              super.volumes),
          },
        },
      },
    },
  },
}