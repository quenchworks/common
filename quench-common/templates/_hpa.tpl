{{/*
HorizontalPodAutoscaler (autoscaling/v2).

Centralised on evidence: 20 of the 23 charts that ship an HPA had an identical copy.

Flexible on purpose -- targetKind/targetName so a StatefulSet chart can scale itself
rather than a Deployment that does not exist, scaling `behavior`, CPU and/or memory
targets, or a fully custom `metrics` list for external/pods/object metrics.
*/}}

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
