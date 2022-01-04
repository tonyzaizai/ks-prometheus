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
    
    [if !std.objectHas($.values.grafana, 'config') || std.length($.values.grafana.config) == 0 then 'config']:
      {
        apiVersion: 'v1',
        kind: 'Secret',
        metadata: {
          name: 'grafana-config',
          namespace: _config.namespace,
          labels: _config.commonLabels,
        },
        type: 'Opaque',
        data: {
                'grafana.ini': std.base64(std.encodeUTF8(grafanaDefConf)),
              } +
              if _config.ldap != null then { 'ldap.toml': std.base64(std.encodeUTF8(_config.ldap)) } else {},
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

            volumes: std.map(function(v) if std.objectHas($.values.grafana, 'storage') && std.length($.values.grafana.storage) > 0 && v.name == 'grafana-storage' then {
              name: v.name, 
              persistentVolumeClaim: {claimName: 'grafana-storage'},
            } else v, super.volumes) 
            + if !std.objectHas($.values.grafana, 'config') || std.length($.values.grafana.config) == 0 then [{ 
              name: 'grafana-config', 
              secret: { secretName: 'grafana-config' },
            }] else [],

            containers: if !std.objectHas($.values.grafana, 'config') || std.length($.values.grafana.config) == 0 then std.map(
              function(c)
                if c.name != 'grafana' then c
                else c { 
                  volumeMounts+: [{ name: 'grafana-config', mountPath: '/etc/grafana', readOnly: false }],
                },
            super.containers) else super.containers,
          },
        },
      },
    },
  },
}