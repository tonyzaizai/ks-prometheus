local k8s = import '../lib/k8s.libsonnet';

// copy from 'kubernetes-mixin/lib/add-runbook-links.libsonnet'
local lower(x) =
  local cp(c) = std.codepoint(c);
  local lowerLetter(c) =
    if cp(c) >= 65 && cp(c) < 91
    then std.char(cp(c) + 32)
    else c;
  std.join('', std.map(lowerLetter, std.stringChars(x)));

{
    local namespace = $.values.common.namespace,
    local runbookURLPrefix = if 'runbookURLPrefix' in $.values.common then std.rstripChars($.values.common.runbookURLPrefix, '/') else '',
    // parse prometheusAlerts to GlobalRuleGroup List
    local groupResourcesList(prometheusAlerts, runbookCategory) = {
        local runbookURLPattern = 
            if runbookURLPrefix == null || runbookURLPrefix == '' || runbookCategory == null || runbookCategory == '' then ''
            else runbookURLPrefix + "/" + runbookCategory + "/%s",
        apiVersion: 'v1',
        kind: 'List',
        items: std.map(function(group) {
            local initResource = self + {metadata+: {annotations: {},}},
            apiVersion: 'alerting.kubesphere.io/v2beta1',
            kind: 'GlobalRuleGroup',
            metadata: {
                name: k8s.sanitizeName(group.name),
                namespace: namespace,
                labels: {
                  "alerting.kubesphere.io/enable": "true",
                  "alerting.kubesphere.io/builtin": "true", 
                },
                annotations: {
                    "alerting.kubesphere.io/initial-configuration": std.manifestJsonMinified(initResource),
                },
            },
            spec: {
                [if std.objectHas(group, 'interval') then 'interval']: group.interval,
                [if std.objectHas(group, 'partial_response_strategy') then 'partial_response_strategy']: group['partial_response_strategy'],
                rules: std.filterMap(
                    function(rule) rule.alert != "" && rule.expr != "",
                    function(rule) rule + {
                        [if std.objectHas(rule, 'labels') then 'labels']: 
                            std.foldl(
                                function(last, field) last + {[if field != "severity" then field]: rule.labels[field]}, 
                                std.objectFields(rule.labels), {}),
                        [if std.objectHas(rule, 'labels') && std.objectHas(rule.labels, 'severity') then 'severity']: rule.labels.severity,
                        annotations+: {
                            [if runbookURLPattern!='' then 'runbook_url']: runbookURLPattern % lower(rule.alert),
                        },
                    }, 
                    group.rules),
            },
        }, prometheusAlerts.groups),
    },  

    kubernetesControlPlane+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "kubernetes"),
    },
    alertmanager+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "alertmanager"),
    },
    kubeStateMetrics+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "kube-state-metrics"),
    },
    nodeExporter+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "node"),
    },
    prometheus+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "prometheus"),
    } + 
        (if std.objectHasAll($.values.prometheus, 'thanos') && $.values.prometheus.thanos != null then {
            mixinThanos+:: {prometheusAlerts+:: {groups: []}},
            alertRuleGroupsThanos: groupResourcesList(super.mixinThanos.prometheusAlerts, "thanos"),
        } else {}) +
        (if std.objectHasAll($.values, 'etcd') && $.values.etcd != null then {
            mixinEtcd+:: {prometheusAlerts+:: {groups: []}},
            alertRuleGroupsEtcd: groupResourcesList(super.mixinEtcd.prometheusAlerts, "etcd"),
        } else {}),
    prometheusOperator+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "prometheus-operator"),
    },
    kubePrometheus+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "general"),
    },
    thanosRuler+: {
        mixin+:: {prometheusAlerts+:: {groups: []}},
        alertRuleGroups: groupResourcesList(super.mixin.prometheusAlerts, "thanos"),
    },
}