{{/*
Create guestbook frontend name.
*/}}
{{- define "guestbook.frontend.fullname" -}}
{{- printf "%s-%s" (include "guestbook.fullname" .) .Values.frontend.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create guestbook backend name.
*/}}
{{- define "guestbook.backend.fullname" -}}
{{- printf "%s-%s" (include "guestbook.fullname" .) .Values.backend.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create guestbook backend env secret name for external secret and secret.
*/}}
{{- define "guestbook.backend.env.fullname" -}}
{{- printf "%s-%s" (include "guestbook.backend.fullname" .) "env" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
