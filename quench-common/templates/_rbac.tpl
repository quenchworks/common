{{/*
Shared ServiceAccount + RBAC scaffolding.

Across the catalog these objects are near-identical: a Role and RoleBinding named
after the release, bound to the chart's ServiceAccount in the release namespace,
and 130 charts each carry their own copy of the SAME serviceAccountName logic.
What is genuinely app-specific is only the RULES, so those come from values and
everything around them is shared.

An app chart opts in with:

    templates/serviceaccount.yaml   {{- include "quench-common.serviceAccount" . }}
    templates/rbac.yaml             {{- include "quench-common.rbac" . }}

Charts needing several Roles, aggregated ClusterRoles, or per-component subjects
(harbor, argocd, thanos) keep a bespoke template -- this covers the single-subject
case, which is the overwhelming majority.
*/}}

{{/*
Resolve the ServiceAccount name. Identical semantics to the per-chart
"<chart>.serviceAccountName" helpers this replaces: when the chart creates the
account the default is the release fullname; when it does not, an unset name means
the namespace "default" account.
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

{{/*
Role + RoleBinding (namespaced), and optionally ClusterRole + ClusterRoleBinding
when rbac.clusterScoped is true -- some controllers genuinely need cluster reads.
Rules come from values and default to EMPTY, which is deliberate: an empty Role
grants nothing, so a chart that has not declared its rules cannot accidentally get
permissions it did not ask for.
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
