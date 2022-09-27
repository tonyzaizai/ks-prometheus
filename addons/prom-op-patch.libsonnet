

{
  pruneCrd(a, fieldName):: // Recursively remove all members named by fieldName which has a sibling named 'type'.
    if std.isArray(a) then
      [$.pruneCrd(x, fieldName) for x in a]
    else if std.isObject(a) then 
        if std.objectHas(a, 'type') then 
        {
            [x]: $.pruneCrd(a[x], fieldName)
            for x in std.objectFields(a)
            if x != fieldName
        } else {
            [x]: $.pruneCrd(a[x], fieldName)
            for x in std.objectFields(a)
        } 
    else
        a,

  prometheusOperator+: {
    local mixinConfig = super._config.mixin._config,
    mixin:: (import './prom-op-mixin/mixin.libsonnet') + 
      (import 'github.com/kubernetes-monitoring/kubernetes-mixin/lib/add-runbook-links.libsonnet') {
        _config+:: mixinConfig,
      },

    local promcrd = super['0prometheusCustomResourceDefinition'],
    '0prometheusCustomResourceDefinition': $.pruneCrd(promcrd, "description"), 
  },
}