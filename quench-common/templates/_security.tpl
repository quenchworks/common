{{/*
Hardened pod-level security context. Locked-down defaults that callers may extend
through .Values.podSecurityContext (user keys win, so the defaults stay unless
deliberately overridden, e.g. fsGroupChangePolicy or supplementalGroups for a volume).
*/}}
{{- define "quench-common.podSecurityContext" -}}
{{- $default := dict "runAsNonRoot" true "runAsUser" 1001 "runAsGroup" 1001 "fsGroup" 1001 "seccompProfile" (dict "type" "RuntimeDefault") -}}
{{- $override := deepCopy (.Values.podSecurityContext | default dict) -}}
{{- toYaml (mergeOverwrite $default $override) -}}
{{- end -}}

{{/*
Hardened container-level security context. Same merge contract: the hardened
defaults hold unless .Values.containerSecurityContext overrides a specific key.
*/}}
{{- define "quench-common.containerSecurityContext" -}}
{{- $default := dict "allowPrivilegeEscalation" false "readOnlyRootFilesystem" true "privileged" false "capabilities" (dict "drop" (list "ALL")) -}}
{{- $override := deepCopy (.Values.containerSecurityContext | default dict) -}}
{{- toYaml (mergeOverwrite $default $override) -}}
{{- end -}}
