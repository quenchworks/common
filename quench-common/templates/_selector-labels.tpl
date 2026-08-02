{{/*
Selector labels -- the labels a Deployment/StatefulSet/Service uses to FIND its pods.

READ THIS BEFORE ADDING ANY: `spec.selector` is IMMUTABLE on Deployment, StatefulSet,
DaemonSet and Job. Once a workload exists, changing its selector makes every later
`helm upgrade` fail with

    field is immutable

and the only way out is deleting and recreating the workload (downtime, and for a
StatefulSet a careful dance with its PVCs). So selector labels are deliberately kept
to the two that identify a release, and everything else goes on the pod template or
on object metadata instead, where labels are freely mutable.

Three separate knobs, because they have three different blast radii:

  selectorLabels   .Values.selectorLabels   IMMUTABLE after install -- set at install
                                            time only, never on an existing release
  podLabels        .Values.podLabels        pod template only, safe to change anytime
  commonLabels     .Values.commonLabels     every object's metadata, safe to change

If you only want a label for querying (`kubectl get -l team=platform`), use
commonLabels or podLabels. Reach for selectorLabels only when a label genuinely has
to participate in pod selection, and then set it before the first install.
*/}}

{{- define "quench-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "quench-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Values.selectorLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
The selector labels WITHOUT the user additions. Use this where a template must match
an object created by an earlier chart version whose selector predates any custom
selectorLabels -- it lets a chart keep matching an existing workload while still
labelling new objects richly.
*/}}
{{- define "quench-common.selectorLabelsBase" -}}
app.kubernetes.io/name: {{ include "quench-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
