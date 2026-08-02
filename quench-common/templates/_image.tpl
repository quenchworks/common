{{/*
Image resolution. The contract with the image factory: charts reference images only by
repository and digest, never a mutable tag.
*/}}

{{/*
Resolve the image strictly by digest. Refusing a tag-only reference is deliberate: it
guarantees the deployed artifact is exactly the one the image factory scanned and
signed. registry is optional and only prepended when set, so an air-gapped mirror can
be pointed at without rewriting every repository string.
*/}}
{{- define "quench-common.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $digest := required "image.digest is required (Quenchworks pins by digest, never a tag)" .Values.image.digest -}}
{{- with .Values.image.registry -}}
{{- printf "%s/%s@%s" (trimSuffix "/" .) $repo $digest -}}
{{- else -}}
{{- printf "%s@%s" $repo $digest -}}
{{- end -}}
{{- end -}}

{{/*
imagePullSecrets, from image.pullSecrets or the chart-level imagePullSecrets. Accepts
either plain strings or {name: ...} maps, since both spellings are common in the wild.
Emits nothing when none are set.
*/}}
{{- define "quench-common.imagePullSecrets" -}}
{{- $secrets := concat ((.Values.image).pullSecrets | default list) (.Values.imagePullSecrets | default list) -}}
{{- if $secrets }}
imagePullSecrets:
{{- range $secrets }}
{{- if kindIs "string" . }}
  - name: {{ . }}
{{- else }}
  - {{ toYaml . | nindent 4 | trim }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
