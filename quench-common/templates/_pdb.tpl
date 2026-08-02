*/}}

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
