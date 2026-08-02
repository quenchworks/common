{{/*
Naming. Split out of _helpers.tpl so each concern lives in one file.

  quench-common.name       chart name, overridable with nameOverride
  quench-common.fullname   release-scoped name used for nearly every object
*/}}

{{- define "quench-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
fullname is "<release>-<name>". fullnameOverride replaces it outright, which is what
you want when an application compiles its own object names in and cannot tolerate a
release prefix.
*/}}
{{- define "quench-common.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
