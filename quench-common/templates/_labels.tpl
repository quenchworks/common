{{/*
Object metadata labels. Freely mutable, unlike the selector labels in
_selector-labels.tpl, so this is where extra labels belong.

  quench-common.labels        the standard set + .Values.commonLabels
  quench-common.podTemplateLabels  selector labels + .Values.podLabels, for a pod template
*/}}

{{- define "quench-common.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "quench-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{/* part-of identifies the catalogue by default. An app that REQUIRES a specific value
     overrides it -- Argo CD is the real case: its settings manager only sees
     ConfigMaps/Secrets labelled app.kubernetes.io/part-of=argocd, so with the default
     its own config is invisible and every component dies on "configmap not found". */}}
app.kubernetes.io/part-of: {{ .Values.partOf | default "quenchworks" }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Labels for a pod template: the selector labels (so the workload matches its pods) plus
any podLabels. Never put podLabels in the selector -- see _selector-labels.tpl.
*/}}
{{- define "quench-common.podTemplateLabels" -}}
{{ include "quench-common.selectorLabels" . }}
{{- with .Values.podLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Annotations for every object, from .Values.commonAnnotations. Emits nothing when unset,
so a template can use `{{- with (include "quench-common.commonAnnotations" .) }}`.
*/}}
{{- define "quench-common.commonAnnotations" -}}
{{- with .Values.commonAnnotations }}
{{- toYaml . }}
{{- end }}
{{- end -}}
