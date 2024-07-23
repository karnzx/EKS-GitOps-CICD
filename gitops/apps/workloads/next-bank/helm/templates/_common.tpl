{{/*
Expand the name of the chart.
*/}}
{{- define "guestbook.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "guestbook.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "guestbook.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create guestbook app version
*/}}
{{- define "guestbook.defaultTag" -}}
{{- default .Chart.AppVersion .Values.global.image.tag }}
{{- end -}}

{{/*
Return valid version label
*/}}
{{- define "guestbook.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "guestbook.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "guestbook.labels" -}}
helm.sh/chart: {{ include "guestbook.chart" .context }}
{{ include "guestbook.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: guestbook
app.kubernetes.io/version: {{ include "guestbook.versionLabelValue" .context }}
{{- with .context.Values.global.additionalLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "guestbook.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "guestbook.name" .context }}-{{ .name }}
{{ end -}}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Common affinity definition
Pod affinity
  - Soft prefers different nodes
  - Hard requires different nodes and prefers different availibility zones
Node affinity
  - Soft prefers given user expressions
  - Hard requires given user expressions
*/}}
{{- define "guestbook.affinity" -}}
{{- with .component.affinity -}}
  {{- toYaml . -}}
{{- else -}}
{{- $preset := .context.Values.global.affinity -}}
{{- if (eq $preset.podAntiAffinity "soft") }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "guestbook.name" .context }}-{{ .component.name }}
      topologyKey: kubernetes.io/hostname
{{- else if (eq $preset.podAntiAffinity "hard") }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: {{ include "guestbook.name" .context }}-{{ .component.name }}
      topologyKey: topology.kubernetes.io/zone
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchLabels:
        app.kubernetes.io/name: {{ include "guestbook.name" .context }}-{{ .component.name }}
    topologyKey: kubernetes.io/hostname
{{- end }}
{{- with $preset.nodeAffinity.matchExpressions }}
{{- if (eq $preset.nodeAffinity.type "soft") }}
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 1
    preference:
      matchExpressions:
      {{- toYaml . | nindent 6 }}
{{- else if (eq $preset.nodeAffinity.type "hard") }}
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      {{- toYaml . | nindent 6 }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common deployment strategy definition
- Recreate don't have additional fields, we need to remove them if added by the mergeOverwrite
*/}}
{{- define "guestbook.strategy" -}}
{{- $preset := . -}}
{{- if (eq (toString $preset.type) "Recreate") }}
type: Recreate
{{- else if (eq (toString $preset.type) "RollingUpdate") }}
type: RollingUpdate
{{- with $preset.rollingUpdate }}
rollingUpdate:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}