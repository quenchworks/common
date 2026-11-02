{{/*
Opt-in TLS for the app's own listener (app-native TLS, not an Ingress or a sidecar).

The library owns the certificate; the chart owns the wiring. A chart opts in with a
one-line templates/tls.yaml:

    {{- include "quench-common.tls.resources" . }}

mounts the Secret into the app container:

    volumes:      {{- include "quench-common.tls.volume" . | nindent 8 }}
    volumeMounts: {{- include "quench-common.tls.volumeMount" . | nindent 12 }}

and turns on the app's own TLS with /tls/tls.crt, /tls/tls.key (and /tls/ca.crt for
clients that verify). The values block, DISABLED by default:

    tls:
      enabled: false
      existingSecret: ""          # 1st: a kubernetes.io/tls Secret you manage
      certManager:
        enabled: false            # 2nd: a cert-manager Certificate
        issuerRef: { name: "", kind: ClusterIssuer }
        dnsNames: []              # default: the Service names below
        duration: ""              # e.g. 2160h; empty = issuer default
      selfSigned:
        validityDays: 365         # 3rd (default): a Helm-generated CA + cert

The first source that is set wins, so enabling TLS with nothing else configured gives
a self-signed certificate: it works out of the box and browsers warn. The self-signed
Secret is reused on upgrade (lookup), so clients that trusted its ca.crt keep working;
`helm template` has no cluster and always generates a fresh one.

Nonroot containers cannot bind ports below 1024, so an HTTP app listens on its own
TLS port (8443 by convention) and the chart's Service publishes it as 443. A
non-HTTP app (PostgreSQL, Redis, Kafka) keeps its protocol port and speaks TLS there.
*/}}

{{- define "quench-common.tls.enabled" -}}
{{- if and .Values.tls .Values.tls.enabled }}true{{ end -}}
{{- end -}}

{{/* The Secret the app mounts, whichever source made it. */}}
{{- define "quench-common.tls.secretName" -}}
{{- if .Values.tls.existingSecret -}}
{{- .Values.tls.existingSecret -}}
{{- else -}}
{{- printf "%s-tls" (include "quench-common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Default SANs: the Service in every form a client may dial, plus its pods by name. */}}
{{- define "quench-common.tls.dnsNames" -}}
{{- $fn := include "quench-common.fullname" . -}}
{{- $ns := .Release.Namespace -}}
{{- $names := list $fn (printf "%s.%s" $fn $ns) (printf "%s.%s.svc" $fn $ns) (printf "%s.%s.svc.cluster.local" $fn $ns) "localhost" -}}
{{- $names = append $names (printf "*.%s-headless.%s.svc" $fn $ns) -}}
{{- $names = append $names (printf "*.%s-headless.%s.svc.cluster.local" $fn $ns) -}}
{{- $extra := list -}}
{{- if and .Values.tls.certManager .Values.tls.certManager.dnsNames -}}
{{- $extra = .Values.tls.certManager.dnsNames -}}
{{- end -}}
{{- concat $names $extra | uniq | toJson -}}
{{- end -}}

{{/* The Certificate or Secret behind tls.secretName. Nothing when TLS is off or the user brings a Secret. */}}
{{- define "quench-common.tls.resources" -}}
{{- if and (include "quench-common.tls.enabled" .) (not .Values.tls.existingSecret) -}}
{{- $name := include "quench-common.tls.secretName" . -}}
{{- $cm := .Values.tls.certManager | default dict -}}
{{- if $cm.enabled -}}
{{- if not (and $cm.issuerRef $cm.issuerRef.name) -}}
{{- fail "tls.certManager.enabled needs tls.certManager.issuerRef.name" -}}
{{- end -}}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
spec:
  secretName: {{ $name }}
  commonName: {{ include "quench-common.fullname" . }}
  dnsNames: {{ include "quench-common.tls.dnsNames" . }}
  {{- with $cm.duration }}
  duration: {{ . }}
  {{- end }}
  issuerRef:
    name: {{ $cm.issuerRef.name }}
    kind: {{ $cm.issuerRef.kind | default "ClusterIssuer" }}
    group: cert-manager.io
{{- else -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
{{- $crt := "" -}}{{- $key := "" -}}{{- $ca := "" -}}
{{- if and $existing $existing.data (index $existing.data "tls.crt") -}}
{{- $crt = index $existing.data "tls.crt" -}}
{{- $key = index $existing.data "tls.key" -}}
{{- $ca = index $existing.data "ca.crt" | default "" -}}
{{- else -}}
{{- $days := int ((.Values.tls.selfSigned | default dict).validityDays | default 365) -}}
{{- $caCert := genCA (printf "%s-ca" (include "quench-common.fullname" .)) $days -}}
{{- $cert := genSignedCert (include "quench-common.fullname" .) nil (include "quench-common.tls.dnsNames" . | fromJsonArray) $days $caCert -}}
{{- $crt = $cert.Cert | b64enc -}}
{{- $key = $cert.Key | b64enc -}}
{{- $ca = $caCert.Cert | b64enc -}}
{{- end -}}
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "quench-common.labels" . | nindent 4 }}
data:
  tls.crt: {{ $crt }}
  tls.key: {{ $key }}
  ca.crt: {{ $ca }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Pod volume holding the certificate. Emits a list item, or nothing when TLS is off. */}}
{{- define "quench-common.tls.volume" -}}
{{- if include "quench-common.tls.enabled" . }}
- name: tls
  secret:
    secretName: {{ include "quench-common.tls.secretName" . }}
    defaultMode: 0440
{{- end -}}
{{- end -}}

{{/* Container mount at /tls (tls.crt, tls.key, ca.crt). */}}
{{- define "quench-common.tls.volumeMount" -}}
{{- if include "quench-common.tls.enabled" . }}
- name: tls
  mountPath: /tls
  readOnly: true
{{- end -}}
{{- end -}}

{{/*
PKCS#8 copy of the certificate for servers that read PEM keys only in PKCS#8 (most JVM
stacks): Helm's genSignedCert and cert-manager's RSA default write PKCS#1. An init container
(any busybox image) wraps PKCS#1 in the fixed PKCS#8 header (version 0 + rsaEncryption) and
writes /tls-pkcs8/{tls.key,tls.crt,ca.crt,tls-keystore.pem}; tls-keystore.pem is key then chain.
PKCS#8 input passes through. Usage, both only when TLS is on:
  initContainers:  {{ include "quench-common.tls.pkcs8InitContainer" (dict "ctx" . "image" "<busybox ref>") }}
  volumes/mounts:  {{ include "quench-common.tls.pkcs8Volume" . }} / {{ include "quench-common.tls.pkcs8VolumeMount" . }}
*/}}
{{- define "quench-common.tls.pkcs8InitContainer" -}}
{{- $ctx := .ctx -}}
{{- if include "quench-common.tls.enabled" $ctx }}
- name: tls-pkcs8
  image: {{ .image | quote }}
  securityContext:
    {{- include "quench-common.containerSecurityContext" $ctx | nindent 4 }}
  command:
    - /bin/sh
    - -c
    - |
      set -eu
      derlen() { if [ "$1" -lt 128 ]; then printf '%02x' "$1"; elif [ "$1" -lt 256 ]; then printf '81%02x' "$1"; else printf '82%04x' "$1"; fi; }
      umask 077
      if grep -q 'BEGIN RSA PRIVATE KEY' /tls/tls.key; then
        hex="$(sed '/-----/d' /tls/tls.key | base64 -d | od -An -v -tx1 | tr -d ' \n')"
        oct="04$(derlen $(( ${#hex} / 2 )))$hex"
        inner="020100300d06092a864886f70d0101010500$oct"
        der="30$(derlen $(( ${#inner} / 2 )))$inner"
        { echo "-----BEGIN PRIVATE KEY-----"; printf "$(printf '%s' "$der" | sed 's/../\\x&/g')" | base64 | tr -d '\n' | fold -w 64; echo; echo "-----END PRIVATE KEY-----"; } > /tls-pkcs8/tls.key
      else
        cat /tls/tls.key > /tls-pkcs8/tls.key
      fi
      cat /tls/tls.crt > /tls-pkcs8/tls.crt
      if [ -s /tls/ca.crt ]; then cat /tls/ca.crt > /tls-pkcs8/ca.crt; fi
      cat /tls-pkcs8/tls.key /tls-pkcs8/tls.crt > /tls-pkcs8/tls-keystore.pem
  volumeMounts:
    - name: tls
      mountPath: /tls
      readOnly: true
    - name: tls-pkcs8
      mountPath: /tls-pkcs8
{{- end -}}
{{- end -}}

{{- define "quench-common.tls.pkcs8Volume" -}}
{{- if include "quench-common.tls.enabled" . }}
- name: tls-pkcs8
  emptyDir:
    medium: Memory
{{- end -}}
{{- end -}}

{{- define "quench-common.tls.pkcs8VolumeMount" -}}
{{- if include "quench-common.tls.enabled" . }}
- name: tls-pkcs8
  mountPath: /tls-pkcs8
  readOnly: true
{{- end -}}
{{- end -}}

{{/*
JSON schema fragment for the tls block. Charts with additionalProperties: false paste
this under properties.tls (the library cannot inject into a chart's schema).
*/}}
{{- define "quench-common.tls.schemaDoc" -}}
"tls": {
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "enabled": { "type": "boolean" },
    "existingSecret": { "type": "string" },
    "certManager": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "enabled": { "type": "boolean" },
        "issuerRef": {
          "type": "object",
          "properties": { "name": { "type": "string" }, "kind": { "type": "string", "enum": ["Issuer", "ClusterIssuer"] } }
        },
        "dnsNames": { "type": "array", "items": { "type": "string" } },
        "duration": { "type": "string" }
      }
    },
    "selfSigned": {
      "type": "object",
      "additionalProperties": false,
      "properties": { "validityDays": { "type": "integer", "minimum": 1 } }
    }
  }
}
{{- end -}}
