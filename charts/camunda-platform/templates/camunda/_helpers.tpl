{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "camundaPlatform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (for example,
by the DNS naming spec). If release name contains chart name it will be used as a full name.
*/}}
{{- define "camundaPlatform.fullname" -}}
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
[camunda-platform] Create a default fully qualified app name for component.

Example:
{{ include "camundaPlatform.componentFullname" (dict "componentName" "foo" "componentValues" .Values.foo "context" $) }}
*/}}
{{- define "camundaPlatform.componentFullname" -}}
    {{- if (.componentValues).fullnameOverride -}}
        {{- .componentValues.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- $name := default .componentName (.componentValues).nameOverride -}}
        {{- if contains $name .context.Release.Name -}}
            {{- .context.Release.Name | trunc 63 | trimSuffix "-" -}}
        {{- else -}}
            {{- printf "%s-%s" .context.Release.Name $name | trunc 63 | trimSuffix "-" -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Define common labels, combining the match labels and transient labels, which might change on updating
(version depending). These labels should not be used on matchLabels selector, since the selectors are immutable.
*/}}
{{- define "camundaPlatform.labels" -}}
{{- template "camundaPlatform.matchLabels" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- if .Values.image }}
    {{- if .Values.image.tag }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
    {{- else }}
app.kubernetes.io/version: {{ .Values.global.image.tag | quote }}
    {{- end }}
{{- else }}
app.kubernetes.io/version: {{ .Values.global.image.tag | quote }}
{{- end }}
{{- end }}

{{/*
Common match labels, which are extended by sub-charts and should be used in matchLabels selectors.
*/}}
{{- define "camundaPlatform.matchLabels" -}}
{{- if .Values.global.labels -}}
{{ toYaml .Values.global.labels }}
{{- end }}
app.kubernetes.io/name: {{ template "camundaPlatform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: camunda-platform
{{- end -}}

{{/*
Get image tag according the values of "base" or "overlay" values.
If the "overlay" values exist, they will override the "base" values, otherwise the "base" values will be used.
Usage: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.console) }}
*/}}
{{- define "camundaPlatform.imageTagByParams" -}}
    {{- .overlay.image.tag | default .base.image.tag -}}
{{- end -}}

{{/*
Get image according the values of "base" or "overlay" values.
If the "overlay" values exist, they will override the "base" values, otherwise the "base" values will be used.
Usage: {{ include "camundaPlatform.imageByParams" (dict "base" .Values.global "overlay" .Values.console) }}
*/}}
{{- define "camundaPlatform.imageByParams" -}}
    {{- $imageRegistry := .overlay.image.registry | default .base.image.registry -}}
    {{- printf "%s%s%s:%s"
        $imageRegistry
        (empty $imageRegistry | ternary "" "/")
        (.overlay.image.repository | default .base.image.repository)
        (include "camundaPlatform.imageTagByParams" (dict "base" .base "overlay" .overlay))
    -}}
{{- end -}}

{{/*
Get image according the values of "global" or "subchart" values.
Usage: {{ include "camundaPlatform.image" . }}
*/}}
{{- define "camundaPlatform.image" -}}
    {{ include "camundaPlatform.imageByParams" (dict "base" .Values.global "overlay" .Values) }}
{{- end -}}

{{/*
Get imagePullSecrets according the values of global, subchart, or empty.
*/}}
{{- define "camundaPlatform.subChartImagePullSecrets" -}}
    {{- if (.Values.image.pullSecrets) -}}
        {{- .Values.image.pullSecrets | toYaml -}}
    {{- else if (.Values.global.image.pullSecrets) -}}
        {{- .Values.global.image.pullSecrets | toYaml -}}
    {{- else -}}
        {{- "[]" -}}
    {{- end -}}
{{- end -}}

{{/*
Get imagePullSecrets for top-level components.
Usage:
{{ include "camundaPlatform.imagePullSecrets" (dict "component" "zeebe" "context" $) }}
*/}}
{{- define "camundaPlatform.imagePullSecrets" -}}
    {{- $componentValue := (index $.context.Values .component "image" "pullSecrets") -}}
    {{- $globalValue := (index $.context.Values.global "image" "pullSecrets") -}}
    {{- $componentValue | default $globalValue | default list | toYaml -}}
{{- end -}}


{{/*
[camunda-platform] Create labels for secrets shared between Identity and other components.
TODO: Should be removed and use "camundaPlatform.labels" before 8.4 release.
*/}}
{{- define "camundaPlatform.identityLabels" -}}
{{- if .Values.global.labels -}}
{{ toYaml .Values.global.labels }}
{{- end }}
app.kubernetes.io/name: identity
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: camunda-platform
helm.sh/chart: identity-{{ .Chart.Version | replace "+" "_" }}
{{- if .Values.identity.image }}
{{- if .Values.identity.image.tag }}
app.kubernetes.io/version: {{ .Values.identity.image.tag | quote }}
{{- else }}
app.kubernetes.io/version: {{ .Values.global.image.tag | quote }}
{{- end }}
{{- else }}
app.kubernetes.io/version: {{ .Values.global.image.tag | quote }}
{{- end }}
app.kubernetes.io/component: identity
{{- end }}


{{/*
********************************************************************************
Keycloak templates.
********************************************************************************
*/}}

{{/*
[camunda-platform] Keycloak issuer public URL which used externally for Camunda apps.
*/}}
{{- define "camundaPlatform.authIssuerUrl" -}}
  {{- if .Values.global.identity.auth.issuer -}}
    {{- .Values.global.identity.auth.issuer -}}
  {{- else -}}
    {{- tpl .Values.global.identity.auth.publicIssuerUrl . -}}
  {{- end -}}
{{- end -}}

{{/*
[camunda-platform] Keycloak issuer backend URL which used internally for Camunda apps.
TODO: Refactor the Keycloak config once Console is production ready.
      Most of the Keycloak config is handeled in Identity sub-chart, but it should be in the main chart.
*/}}
{{- define "camundaPlatform.authIssuerBackendUrl" -}}
  {{- if .Values.global.identity.auth.issuerBackendUrl -}}
    {{- .Values.global.identity.auth.issuerBackendUrl -}}
  {{- else -}}
    {{- if .Values.global.identity.keycloak.url -}}
      {{-
        printf "%s://%s:%v%s%s"
          .Values.global.identity.keycloak.url.protocol
          .Values.global.identity.keycloak.url.host
          .Values.global.identity.keycloak.url.port
          .Values.global.identity.keycloak.contextPath
          .Values.global.identity.keycloak.realm
      -}}
    {{- else -}}
      {{- include "identity.keycloak.url" .Subcharts.identity -}}{{- .Values.global.identity.keycloak.realm -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
[camunda-platform] Identity auth type which used internally for Camunda apps.
*/}}
{{- define "camundaPlatform.authType" -}}
  {{- .Values.global.identity.auth.type -}}
{{- end -}}

{{/*
[camunda-platform] Keycloak auth token URL which used internally for Camunda apps.
*/}}
{{- define "camundaPlatform.authIssuerBackendUrlTokenEndpoint" -}}
  {{- if .Values.global.identity.auth.tokenUrl -}}
    {{- .Values.global.identity.auth.tokenUrl -}}
  {{- else -}}
    {{- include "camundaPlatform.authIssuerBackendUrl" . -}}/protocol/openid-connect/token
  {{- end -}}
{{- end -}}

{{/*
[camunda-platform] Keycloak auth certs URL which used internally for Camunda apps.
*/}}
{{- define "camundaPlatform.authIssuerBackendUrlCertsEndpoint" -}}
  {{- if .Values.global.identity.auth.jwksUrl -}}
    {{- .Values.global.identity.auth.jwksUrl -}}
  {{- else -}}
    {{- include "camundaPlatform.authIssuerBackendUrl" . -}}/protocol/openid-connect/certs
  {{- end -}}
{{- end -}}


{{/*
********************************************************************************
Elasticsearch templates.
********************************************************************************
*/}}

{{/*
[camunda-platform] Elasticsearch URL which could be external.
*/}}

{{- define "camundaPlatform.elasticsearchHost" -}}
  {{- tpl .Values.global.elasticsearch.host $ -}}
{{- end -}}

{{- define "camundaPlatform.elasticsearchURL" -}}
  {{- if .Values.global.elasticsearch.url -}}
    {{- .Values.global.elasticsearch.url -}}
  {{- else -}}
    {{ .Values.global.elasticsearch.protocol }}://{{ include "camundaPlatform.elasticsearchHost" . }}:{{ .Values.global.elasticsearch.port }}
  {{- end -}}
{{- end -}}


{{/*
********************************************************************************
Operate templates.
********************************************************************************
*/}}

{{/*
[camunda-platform] Operate internal URL.
*/}}
{{ define "camundaPlatform.operateURL" }}
  {{- if .Values.operate.enabled -}}
    {{- print "http://" -}}{{- include "operate.fullname" . -}}:{{- .Values.operate.service.port -}}
    {{- .Values.operate.contextPath -}}
  {{- end -}}
{{- end -}}


{{/*
********************************************************************************
Identity templates.
********************************************************************************
*/}}

{{/*
[camunda-platform] Identity internal URL.
*/}}
{{ define "camundaPlatform.identityURL" }}
  {{- if .Values.identity.enabled -}}
    {{-
      printf "http://%s:%v%s"
        (include "identity.fullname" .Subcharts.identity)
        .Values.identity.service.port
        (.Values.identity.contextPath | default "")
    -}}
  {{- end -}}
{{- end -}}

{{/*
[camunda-platform] Create the name of the Identity secret for components.
Usage: {{ include "camundaPlatform.identitySecretName" (dict "context" . "component" "zeebe") }}
*/}}
{{- define "camundaPlatform.identitySecretName" -}}
  {{- $releaseName := .context.Release.Name | trunc 63 | trimSuffix "-" -}}
  {{- printf "%s-%s-identity-secret" $releaseName .component -}}
{{- end }}


{{/*
********************************************************************************
Release templates.
********************************************************************************
*/}}

{{ define "camundaPlatform.releaseInfo" -}}
- name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  version: {{ .Chart.Version }}
  components:
  {{- $proto := ternary "https" "http" .Values.global.ingress.tls.enabled -}}
  {{- $baseURL := printf "%s://%s" $proto .Values.global.ingress.host }}
{{- "" }}
  {{ if .Values.console.enabled }}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "console.fullname" .) .Release.Namespace .Values.console.service.managementPort -}}
  - name: Console
    id: console
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.console) }}
    url: {{ $baseURL }}{{ .Values.console.contextPath }}
    readiness: {{ printf "%s%s" $baseURLInternal .Values.console.readinessProbe.probePath }}
    metrics: {{ printf "%s%s" $baseURLInternal .Values.console.metrics.prometheus }}
  {{- end }}
{{- "" }}
  {{- with dict "Release" .Release "Chart" (dict "Name" "identity") "Values" .Values.identity }}
  {{ if .Values.enabled -}}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "identity.fullname" .) .Release.Namespace .Values.service.metricsPort -}}
  - name: Keycloak
    id: keycloak
    version: {{ .Values.keycloak.image.tag }}
    url: {{ $baseURL }}{{ .Values.global.identity.keycloak.contextPath }}
  - name: Identity
    id: identity
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values) }}
    url: {{ $baseURL }}{{ .Values.contextPath }}
    readiness: {{ printf "%s%s" $baseURLInternal .Values.readinessProbe.probePath }}
    metrics: {{ printf "%s%s" $baseURLInternal .Values.metrics.prometheus }}
  {{- end }}
  {{- end }}
{{- "" }}
  {{ if .Values.operate.enabled -}}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "operate.fullname" .) .Release.Namespace .Values.operate.service.port -}}
  - name: Operate
    id: operate
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.operate) }}
    url: {{ $baseURL }}{{ .Values.operate.contextPath }}
    readiness: {{ printf "%s%s%s" $baseURLInternal .Values.operate.contextPath .Values.operate.readinessProbe.probePath }}
    metrics: {{ printf "%s%s%s" $baseURLInternal .Values.operate.contextPath .Values.operate.metrics.prometheus }}
  {{- end }}
{{- "" }}
  {{ if .Values.optimize.enabled -}}
  {{- $baseURLInternal := printf "http://%s.%s" (include "optimize.fullname" .) .Release.Namespace -}}
  - name: Optimize
    id: optimize
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.optimize) }}
    url: {{ $baseURL }}{{ .Values.optimize.contextPath }}
    readiness: {{ printf "%s:%v%s%s" $baseURLInternal .Values.optimize.service.port .Values.optimize.contextPath .Values.optimize.readinessProbe.probePath }}
    metrics: {{ printf "%s:%v%s" $baseURLInternal .Values.optimize.service.managementPort .Values.optimize.metrics.prometheus }}
  {{- end }}
{{- "" }}
  {{ if .Values.tasklist.enabled -}}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "tasklist.fullname" .) .Release.Namespace .Values.tasklist.service.port -}}
  - name: Tasklist
    id: tasklist
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.tasklist) }}
    url: {{ $baseURL }}{{ .Values.tasklist.contextPath }}
    readiness: {{ printf "%s%s%s" $baseURLInternal .Values.tasklist.contextPath .Values.tasklist.readinessProbe.probePath }}
    metrics: {{ printf "%s%s%s" $baseURLInternal .Values.tasklist.contextPath .Values.tasklist.metrics.prometheus }}
  {{- end }}
{{- "" }}
  {{ if .Values.webModeler.enabled }}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "webModeler.webapp.fullname" .) .Release.Namespace .Values.webModeler.webapp.service.managementPort -}}
  - name: WebModeler WebApp
    id: webModelerWebApp
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.webModeler) }}
    url: {{ $baseURL }}{{ .Values.webModeler.contextPath }}
    readiness: {{ printf "%s%s" $baseURLInternal  .Values.webModeler.webapp.readinessProbe.probePath }}
    metrics: {{ printf "%s%s" $baseURLInternal .Values.webModeler.webapp.metrics.prometheus }}
  {{- end }}
{{- "" }}
  {{ if .Values.zeebe.enabled -}}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "zeebe.names.gateway" . | trimAll "\"") .Release.Namespace .Values.zeebeGateway.service.httpPort -}}
  - name: Zeebe Gateway
    id: zeebeGateway
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.zeebe) }}
    url: grpc://{{ tpl .Values.zeebeGateway.ingress.host $ }}
    readiness: {{ printf "%s%s" $baseURLInternal .Values.zeebeGateway.readinessProbe.probePath }}
    metrics: {{ printf "%s%s" $baseURLInternal .Values.zeebeGateway.metrics.prometheus }}
  {{- $baseURLInternal := printf "http://%s.%s:%v" (include "zeebe.names.broker" . | trimAll "\"") .Release.Namespace .Values.zeebe.service.httpPort }}
  - name: Zeebe
    id: zeebe
    version: {{ include "camundaPlatform.imageTagByParams" (dict "base" .Values.global "overlay" .Values.zeebeGateway) }}
    readiness: {{ printf "%s%s" $baseURLInternal .Values.zeebe.readinessProbe.probePath }}
    metrics: {{ printf "%s%s" $baseURLInternal .Values.zeebe.metrics.prometheus }}
  {{- end }}
{{- end -}}
