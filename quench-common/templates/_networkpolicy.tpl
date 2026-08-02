{{/*
NetworkPolicy.

NOT a fixed policy, and that is the point: 128 charts produced 91 distinct shapes,
because every application allows a different set of ports. So the ports come from
values, and a chart may pass its historical default in.

Call it either way:

    {{- include "quench-common.networkPolicy" . }}
    {{- include "quench-common.networkPolicy" (dict "ctx" . "defaultPorts" (list (dict "port" "http" "protocol" "TCP"))) }}

Flexible on purpose -- ingressPorts, extraFrom peers (namespaceSelector, ipBlock),
wholesale ingress/egress rule lists, and denyAllEgress (policyTypes lists Egress with
no rules, which is how the API expresses deny-all).
*/}}

{{- define "quench-common.networkPolicy" -}}
{{- $ctx := . -}}
{{- $defaults := list -}}
{{- if kindIs "map" . -}}
  {{- if hasKey . "ctx" -}}
    {{- $ctx = .ctx -}}
    {{- $defaults = .defaultPorts | default list -}}
  {{- end -}}
{{- end -}}
{{- $n := $ctx.Values.networkPolicy | default dict -}}
{{- if $n.enabled -}}
{{- $ports := $n.ingressPorts | default $defaults -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "quench-common.fullname" $ctx }}
  labels:
    {{- include "quench-common.labels" $ctx | nindent 4 }}
    {{- with $n.extraLabels }}{{- toYaml . | nindent 4 }}{{- end }}
  {{- with $n.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  podSelector:
    matchLabels:
      {{- include "quench-common.selectorLabels" $ctx | nindent 6 }}
  policyTypes:
    - Ingress
    {{- if or $n.egress $n.denyAllEgress }}
    - Egress
    {{- end }}
  ingress:
    {{- if $n.ingress }}
    {{/* Wholesale custom rules. */}}
    {{- toYaml $n.ingress | nindent 4 }}
    {{- else }}
    - {{ if $ports }}ports:
        {{- toYaml $ports | nindent 8 }}
      {{ end }}
      {{- if not $n.allowExternal }}
      {{/* Same-namespace only. extraFrom appends further peers (namespaceSelector
           for an ingress controller, ipBlock for a VPN range, ...). */}}
      from:
        - podSelector: {}
        {{- with $n.extraFrom }}{{- toYaml . | nindent 8 }}{{- end }}
      {{- else }}
      {{- with $n.extraFrom }}
      from:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
    {{- end }}
  {{- if $n.egress }}
  egress:
    {{- toYaml $n.egress | nindent 4 }}
  {{- else if $n.denyAllEgress }}
  {{/* policyTypes lists Egress with no rules = deny all egress. */}}
  egress: []
  {{- end }}
{{- end -}}
{{- end -}}
