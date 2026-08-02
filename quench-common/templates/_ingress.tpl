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

Backend service: "quench-common.fullname", i.e. the chart's own Service. The port is
resolved from whichever service shape the chart uses (see below); an explicit
`ingress.servicePort` always wins, and exists because a chart may expose several
ports (metrics, grpc, replication) where none of the conventional names fit.

Multi-component charts (harbor, argocd, thanos) do NOT use this: their Ingress has
to route different paths to different Services, so they keep a bespoke template.
*/}}
{{/*
Two call forms.

  {{- include "quench-common.ingress" . }}

    An app chart fronting its OWN Service. Backend = quench-common.fullname, port
    resolved from the chart's service values.

  {{- include "quench-common.ingress" (dict "ctx" . "serviceName" (printf "%s-grafana" .Release.Name) "port" 3000) }}

    An UMBRELLA chart fronting a SUBCHART's Service. Stacks (lgtm-stack,
    observability-stack, identity-stack, ...) have no Service of their own -- they
    aggregate subcharts -- so the default form would point at
    <release>-<stack>, which does not exist. Passing the backend explicitly is what
    makes an Ingress possible there at all. `port` may be omitted to fall back to the
    normal resolution against .Values.service.
*/}}
{{- define "quench-common.ingress" -}}
{{- $ctx := . -}}
{{- $svcOverride := "" -}}
{{- $portOverride := "" -}}
{{- if and (kindIs "map" .) (hasKey . "ctx") -}}
{{- $ctx = .ctx -}}
{{- $svcOverride = .serviceName | default "" -}}
{{- $portOverride = .port | default "" -}}
{{- end -}}
{{- with $ctx -}}
{{- if .Values.ingress.enabled -}}
{{/*
Port resolution, in order. Counted across the 83 charts that adopt this helper, the
catalogue uses FOUR service shapes:

    63  service.port                    single-port charts (opa 8181, ...)
    14  service.httpPort                HTTP alongside a protocol port
                                        (clickhouse 8123 + nativePort, cockroachdb
                                        8080 + sqlPort, elasticsearch 9200 + transportPort)
     4  service.ports.<name>            nested multi-port map (dex 5556 + grpc + telemetry)
     2  service.apiPort                 vault / openbao, whose API is HTTP

All are understood, so enabling ingress needs nothing but a host in the common case.
When NONE resolves the template FAILS with the list it tried, rather than guessing a
port -- guessing would route HTTP traffic at whatever that port actually speaks
(Postgres wire protocol, the Elasticsearch transport protocol) and the failure would
surface as a confusing 502 instead of a clear message at install time.
*/}}
{{- $svcv := .Values.service | default dict -}}
{{- $ports := ($svcv.ports) | default dict -}}
{{- $port := $portOverride | default .Values.ingress.servicePort -}}
{{- if not $port -}}{{- $port = $svcv.port -}}{{- end -}}
{{- if not $port -}}{{- $port = $ports.http -}}{{- end -}}
{{- if not $port -}}{{- $port = $ports.https -}}{{- end -}}
{{- if not $port -}}{{- $port = $svcv.httpPort -}}{{- end -}}
{{- if not $port -}}{{- $port = $svcv.httpsPort -}}{{- end -}}
{{- if not $port -}}{{- $port = $svcv.apiPort -}}{{- end -}}
{{- if not $port -}}
{{- fail "ingress.enabled=true but no HTTP port could be resolved: set ingress.servicePort (tried service.port, service.ports.http/.https, service.httpPort, service.httpsPort, service.apiPort)" -}}
{{- end -}}
{{- if not .Values.ingress.hosts -}}
{{- fail "ingress.enabled=true but ingress.hosts is empty: an Ingress with no rules routes nothing" -}}
{{- end -}}
{{- $svc := $svcOverride | default (include "quench-common.fullname" .) -}}
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
