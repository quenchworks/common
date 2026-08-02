{{/*
PodDisruptionBudget, HorizontalPodAutoscaler and NetworkPolicy.

Measured across the catalogue before centralising any of these: 105/123 charts have
a byte-identical PDB, 104/123 an identical RBAC pair, 20/23 an identical HPA. The
NetworkPolicy is different -- 128 charts produce 91 distinct shapes, because each
app allows different ports -- so its helper is PARAMETERISED by values rather than
fixed, and falls back to the historical "one http port" default.

service.yaml is deliberately NOT here: 128 charts produce 98 distinct shapes, since
the port list is the app's identity. A helper would need as much configuration as
the manifest it replaced.

Every helper below takes values and offers a full escape hatch, so a chart is never
forced to fight the shared template:
  * extraLabels / extraAnnotations on each object
  * `rules` / `metrics` / `ingress` / `egress` passed straight through from values
  * a `spec` override that replaces the generated spec wholesale
*/}}

{{/* ---------------------------------------------------------------- PDB ----- */}}
{{- define "quench-common.pdb" -}}
{{- $p := .Values.podDisruptionBudget | default dict -}}
{{- if $p.enabled -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "quench-common.fullname" . }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
    {{- with $p.extraLabels }}{{- toYaml . | nindent 4 }}{{- end }}
  {{- with $p.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $p.spec }}
  {{/* wholesale override */}}
  {{- toYaml . | nindent 2 }}
  {{- else }}
  {{/* minAvailable and maxUnavailable are mutually exclusive; emit whichever is
       set, preferring maxUnavailable only when minAvailable is absent, and default
       to minAvailable: 1 so an enabled PDB is never empty. */}}
  {{- if $p.maxUnavailable }}
  maxUnavailable: {{ $p.maxUnavailable }}
  {{- else }}
  minAvailable: {{ $p.minAvailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "quench-common.selectorLabels" . | nindent 6 }}
      {{- with $p.extraSelectorLabels }}{{- toYaml . | nindent 6 }}{{- end }}
  {{- with $p.unhealthyPodEvictionPolicy }}
  unhealthyPodEvictionPolicy: {{ . }}
  {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/* ---------------------------------------------------------------- HPA ----- */}}
{{- define "quench-common.hpa" -}}
{{- $a := .Values.autoscaling | default dict -}}
{{- if $a.enabled -}}
{{- $name := include "quench-common.fullname" . -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $name }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
    {{- with $a.extraLabels }}{{- toYaml . | nindent 4 }}{{- end }}
  {{- with $a.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    {{/* Deployment by default, but a StatefulSet chart can point at itself. */}}
    kind: {{ $a.targetKind | default "Deployment" }}
    name: {{ $a.targetName | default $name }}
  minReplicas: {{ $a.minReplicas | default 1 }}
  maxReplicas: {{ $a.maxReplicas | default 3 }}
  {{- with $a.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  metrics:
    {{- if $a.metrics }}
    {{/* Fully custom metrics (external, pods, object) pass straight through. */}}
    {{- toYaml $a.metrics | nindent 4 }}
    {{- else }}
    {{- with $a.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
    {{- with $a.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}

{{/* ------------------------------------------------------ NetworkPolicy ----- */}}
{{/*
Ports differ per app, so this takes them from values. Call with a default port name
for backwards compatibility with the historical single-http-port policy:

    {{- include "quench-common.networkPolicy" (dict "ctx" . "defaultPorts" (list (dict "port" "http" "protocol" "TCP"))) }}

or simply `{{- include "quench-common.networkPolicy" . }}` to take the ports from
networkPolicy.ingressPorts alone.
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
