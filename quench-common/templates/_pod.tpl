{{/*
Shared pod-spec knobs. App charts include these so every chart exposes the same
production surface (scheduling, lifecycle, extensibility) with identical semantics.
Each helper reads standardized .Values keys and emits nothing when the key is unset,
so they are safe to include unconditionally and are backward-compatible.
*/}}

{{/*
Pod-spec-level fields: scheduling and lifecycle. Include directly under
spec.template.spec, e.g. {{- include "quench-common.podSpecFields" . | nindent 6 }}
*/}}
{{- define "quench-common.podSpecFields" -}}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with .Values.schedulerName }}
schedulerName: {{ . }}
{{- end }}
{{- if .Values.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
{{- end }}
{{- end -}}

{{/*
Extra pod labels. Include under spec.template.metadata.labels, after the
selectorLabels block: {{- include "quench-common.podLabels" . | nindent 8 }}
*/}}
{{- define "quench-common.podLabels" -}}
{{- with .Values.podLabels }}
{{- toYaml . }}
{{- end }}
{{- end -}}

{{/*
Pod annotations. Include under spec.template.metadata as a sibling of labels:
  metadata:
    {{- include "quench-common.podAnnotations" . | nindent 6 }}
    labels: ...
*/}}
{{- define "quench-common.podAnnotations" -}}
{{- with .Values.podAnnotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Extra environment variables, appended to a container's env list. The container
template must already have at least one env entry (its built-in vars), then:
  {{- include "quench-common.extraEnvVars" . | nindent 12 }}
*/}}
{{- define "quench-common.extraEnvVars" -}}
{{- with .Values.extraEnvVars }}
{{- toYaml . }}
{{- end }}
{{- end -}}

{{/*
envFrom block sourcing a ConfigMap and/or Secret of env vars. Emits the whole
envFrom: key (or nothing). Include at container level:
  {{- include "quench-common.envFrom" . | nindent 10 }}
*/}}
{{- define "quench-common.envFrom" -}}
{{- if or .Values.extraEnvVarsCM .Values.extraEnvVarsSecret }}
envFrom:
  {{- with .Values.extraEnvVarsCM }}
  - configMapRef:
      name: {{ . }}
  {{- end }}
  {{- with .Values.extraEnvVarsSecret }}
  - secretRef:
      name: {{ . }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Extra volume mounts, appended to a container's volumeMounts list:
  {{- include "quench-common.extraVolumeMounts" . | nindent 12 }}
*/}}
{{- define "quench-common.extraVolumeMounts" -}}
{{- with .Values.extraVolumeMounts }}
{{- toYaml . }}
{{- end }}
{{- end -}}

{{/*
Extra volumes, appended to a pod's volumes list:
  {{- include "quench-common.extraVolumes" . | nindent 8 }}
*/}}
{{- define "quench-common.extraVolumes" -}}
{{- with .Values.extraVolumes }}
{{- toYaml . }}
{{- end }}
{{- end -}}

{{/*
initContainers block. Emits the whole initContainers: key (or nothing). Include
under spec.template.spec: {{- include "quench-common.initContainers" . | nindent 6 }}
*/}}
{{- define "quench-common.initContainers" -}}
{{- with .Values.initContainers }}
initContainers:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Sidecar containers, appended to a pod's containers list (after the main one):
  {{- include "quench-common.sidecars" . | nindent 8 }}
*/}}
{{- define "quench-common.sidecars" -}}
{{- with .Values.sidecars }}
{{- toYaml . }}
{{- end }}
{{- end -}}

{{/*
Container lifecycle hooks. Emits the whole lifecycle: key (or nothing):
  {{- include "quench-common.lifecycleHooks" . | nindent 10 }}
*/}}
{{- define "quench-common.lifecycleHooks" -}}
{{- with .Values.lifecycleHooks }}
lifecycle:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Optional container command/args overrides. Each emits its key only when set:
  {{- include "quench-common.command" . | nindent 10 }}
  {{- include "quench-common.args" . | nindent 10 }}
*/}}
{{- define "quench-common.command" -}}
{{- with .Values.command }}
command:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "quench-common.args" -}}
{{- with .Values.args }}
args:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Resolve a probe: if .Values.<name>Probe.enabled is false, emit nothing; if a
customXxxProbe is set, emit that; otherwise emit the chart's default probe block
merged with timing overrides from .Values.<name>Probe. Call with a dict:
  {{- include "quench-common.probe" (dict "ctx" . "name" "liveness" "default" $probe) | nindent 10 }}
where $probe is the chart's default probe map (handler + timings).
*/}}
{{- define "quench-common.probe" -}}
{{- $ctx := .ctx -}}
{{- $name := .name -}}
{{- $values := index $ctx.Values (printf "%sProbe" $name) | default dict -}}
{{- $custom := index $ctx.Values (printf "custom%sProbe" (title $name)) | default dict -}}
{{- if and (hasKey $values "enabled") (not $values.enabled) -}}
{{- else if not (empty $custom) -}}
{{ printf "%sProbe" $name }}:
  {{- toYaml $custom | nindent 2 }}
{{- else -}}
{{- $probe := deepCopy .default -}}
{{- range $k := list "initialDelaySeconds" "periodSeconds" "timeoutSeconds" "successThreshold" "failureThreshold" -}}
{{- if hasKey $values $k -}}{{- $_ := set $probe $k (index $values $k) -}}{{- end -}}
{{- end -}}
{{ printf "%sProbe" $name }}:
  {{- toYaml $probe | nindent 2 }}
{{- end -}}
{{- end -}}
