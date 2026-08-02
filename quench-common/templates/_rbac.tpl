*/}}

{{- define "quench-common.rbac" -}}
{{- $rbac := .Values.rbac | default dict -}}
{{- if $rbac.create -}}
{{- $name := include "quench-common.fullname" . -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $name }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
rules:
  {{- toYaml ($rbac.rules | default list) | nindent 2 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $name }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ $name }}
subjects:
  - kind: ServiceAccount
    name: {{ include "quench-common.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
{{- if $rbac.clusterScoped }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ $name }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
rules:
  {{- toYaml ($rbac.clusterRules | default list) | nindent 2 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  {{/* Cluster-scoped names are GLOBAL, so they carry the namespace: two releases of
       the same chart in different namespaces would otherwise fight over one object
       and the second install would silently steal the first one's binding. */}}
  name: {{ printf "%s-%s" $name .Release.Namespace | trunc 63 | trimSuffix "-" }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ $name }}
subjects:
  - kind: ServiceAccount
    name: {{ include "quench-common.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
{{- end }}
{{- end -}}
{{- end -}}
