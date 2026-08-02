{{/*
ServiceAccount and its name. 117 of 132 charts had an identical ServiceAccount, and 130
each carried their OWN copy of the same serviceAccountName logic -- that duplication is
what this replaces.
*/}}

{{- define "quench-common.serviceAccountName" -}}
{{- $sa := .Values.serviceAccount | default dict -}}
{{- if $sa.create -}}
{{- default (include "quench-common.fullname" .) $sa.name -}}
{{- else -}}
{{- default "default" $sa.name -}}
{{- end -}}
{{- end -}}

{{- define "quench-common.serviceAccount" -}}
{{- $sa := .Values.serviceAccount | default dict -}}
{{- if $sa.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "quench-common.serviceAccountName" . }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
  {{- with $sa.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{/* Default FALSE, matching every existing chart: most workloads never call the
     API server, and a mounted token is credential exposure for no benefit. Charts
     whose app does talk to the API set this true explicitly. */}}
automountServiceAccountToken: {{ $sa.automountServiceAccountToken | default false }}
{{- end -}}
{{- end -}}
