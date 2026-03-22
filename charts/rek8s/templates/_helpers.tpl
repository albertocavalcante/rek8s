{{/*
rek8s Helm template helpers
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "rek8s.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "rek8s.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rek8s.labels" -}}
helm.sh/chart: {{ include "rek8s.chart" . }}
{{ include "rek8s.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: rek8s
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rek8s.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rek8s.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Chart name and version
*/}}
{{- define "rek8s.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
BES hostname
*/}}
{{- define "rek8s.bes.hostname" -}}
{{- printf "bes.%s" .Values.global.domain }}
{{- end }}

{{/*
BES gRPC hostname
*/}}
{{- define "rek8s.bes.grpcHostname" -}}
{{- printf "bes-grpc.%s" .Values.global.domain }}
{{- end }}

{{/*
RBE hostname
*/}}
{{- define "rek8s.rbe.hostname" -}}
{{- printf "rbe.%s" .Values.global.domain }}
{{- end }}

{{/*
Buildbarn browser hostname
*/}}
{{- define "rek8s.bb.browserHostname" -}}
{{- printf "bb-browser.%s" .Values.global.domain }}
{{- end }}

{{/*
TLS secret name for a given service
*/}}
{{- define "rek8s.tlsSecretName" -}}
{{- printf "%s-%s-tls" (include "rek8s.fullname" .) .component }}
{{- end }}

{{/*
Validate that only one RBE provider is enabled
*/}}
{{- define "rek8s.validateRBE" -}}
{{- if and .Values.rbe.buildfarm.enabled .Values.rbe.buildbarn.enabled }}
{{- fail "Only one RBE provider can be enabled at a time. Set either rbe.buildfarm.enabled or rbe.buildbarn.enabled, not both." }}
{{- end }}
{{- end }}

{{/*
Network policy API version based on provider
*/}}
{{- define "rek8s.networkPolicy.apiVersion" -}}
{{- if eq .Values.cluster.networkPolicy.provider "calico" }}
{{- print "projectcalico.org/v3" }}
{{- else }}
{{- print "networking.k8s.io/v1" }}
{{- end }}
{{- end }}

{{/*
Ingress API version based on provider
*/}}
{{- define "rek8s.ingress.apiVersion" -}}
{{- if eq .Values.cluster.ingress.provider "contour" }}
{{- print "projectcontour.io/v1" }}
{{- else if eq .Values.cluster.ingress.provider "gateway-api" }}
{{- print "gateway.networking.k8s.io/v1" }}
{{- else }}
{{- print "networking.k8s.io/v1" }}
{{- end }}
{{- end }}

{{/*
Annotations for nginx ingress resources.
User-supplied annotations override the built-in defaults.
*/}}
{{- define "rek8s.nginxAnnotations" -}}
{{- $root := .root -}}
{{- $mode := .mode | default "http" -}}
{{- $annotations := dict -}}
{{- $_ := set $annotations "nginx.ingress.kubernetes.io/ssl-redirect" (ternary "true" "false" $root.Values.global.tls.enabled) -}}
{{- if eq $mode "grpc" -}}
{{- $_ := set $annotations "nginx.ingress.kubernetes.io/backend-protocol" "GRPC" -}}
{{- $_ := set $annotations "nginx.ingress.kubernetes.io/proxy-read-timeout" "3600" -}}
{{- $_ := set $annotations "nginx.ingress.kubernetes.io/proxy-send-timeout" "3600" -}}
{{- end -}}
{{- range $key, $value := $root.Values.cluster.ingress.annotations }}
{{- $_ := set $annotations $key $value -}}
{{- end -}}
{{- toYaml $annotations -}}
{{- end }}
