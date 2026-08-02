{{/*
Shared Ingress for app charts. An app chart opts in with a three-line
templates/ingress.yaml:

    {{- include "quench-common.ingress" . }}

and an `ingress:` block in values.yaml that is DISABLED by default, so the chart's
behaviour is unchanged until an operator turns it on.

Only HTTP(S) charts should include this. An Ingress is an HTTP router: in front of
PostgreSQL, Redis, Kafka, MariaDB or etcd it cannot work, because those speak their
own TCP protocols. Expose those with service.type=LoadBalancer or the ingress
controller's TCP passthrough instead -- shipping an `ingress.enabled` knob that
silently does nothing would be worse than not having one.

Backend service: "quench-common.fullname", i.e. the chart's own Service. Port:
`ingress.servicePort` when set, otherwise `service.port`. The override exists
because a chart may expose several ports (metrics, grpc) and the HTTP one is not
always `service.port`.

Multi-component charts (harbor, argocd, thanos) do NOT use this: their Ingress has
to route different paths to different Services, so they keep a bespoke template.
*/}}
{{- define "quench-common.ingress" -}}
{{- if .Values.ingress.enabled -}}
{{/*
Port resolution, in order. The catalogue uses TWO service shapes -- single-port
charts expose `service.port`, multi-port charts (dex, thanos, otel-collector, ...)
expose `service.ports.<name>` -- so both are understood and an explicit override
always wins.
*/}}
{{- $svcv := .Values.service | default dict -}}
{{- $port := .Values.ingress.servicePort -}}
{{- if not $port -}}{{- $port = $svcv.port -}}{{- end -}}
{{- if not $port -}}{{- $port = (($svcv.ports) | default dict).http -}}{{- end -}}
{{- if not $port -}}{{- $port = (($svcv.ports) | default dict).https -}}{{- end -}}
{{- if not $port -}}
{{- fail "ingress.enabled=true but no HTTP port could be resolved: set ingress.servicePort (tried service.port, service.ports.http, service.ports.https)" -}}
{{- end -}}
{{- if not .Values.ingress.hosts -}}
{{- fail "ingress.enabled=true but ingress.hosts is empty: an Ingress with no rules routes nothing" -}}
{{- end -}}
{{- $svc := include "quench-common.fullname" . -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $svc }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{/* Omitted entirely when unset, so the cluster's default IngressClass applies.
       Emitting an empty string would instead mean "no class" and leave the
       Ingress unclaimed by every controller. */}}
  {{- with .Values.ingress.className }}
  ingressClassName: {{ . | quote }}
  {{- end }}
  {{- with .Values.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{/* Default one "/" Prefix path, so the common single-host case needs
               only `hosts: [{host: app.example.com}]`. */}}
          {{- range (.paths | default (list (dict "path" "/" "pathType" "Prefix"))) }}
          - path: {{ .path | default "/" }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $svc }}
                port:
                  number: {{ $port }}
          {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}

{{/*
The values.schema.json fragment every consuming chart needs. Kept here as the single
source of truth for the shape; schemas are per-chart files so it has to be copied in,
but copying from one place keeps all 100+ of them identical.

    "ingress": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "enabled":     { "type": "boolean" },
        "className":   { "type": "string" },
        "annotations": { "type": "object", "additionalProperties": { "type": "string" } },
        "servicePort": { "type": ["integer", "null"], "minimum": 1, "maximum": 65535 },
        "hosts": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["host"],
            "properties": {
              "host": { "type": "string", "minLength": 1 },
              "paths": {
                "type": "array",
                "items": {
                  "type": "object",
                  "additionalProperties": false,
                  "properties": {
                    "path":     { "type": "string" },
                    "pathType": { "type": "string", "enum": ["Prefix", "Exact", "ImplementationSpecific"] }
                  }
                }
              }
            }
          }
        },
        "tls": { "type": "array", "items": { "type": "object" } }
      }
    }
*/}}
