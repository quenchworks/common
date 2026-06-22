# quench-common

[English](README.md) · [العربية](README.ar.md) · **Español**

El **library chart** de Helm compartido que está detrás del catálogo de [QuenchWorks](https://github.com/quenchworks). Es el único lugar donde se define la base de seguridad, así que todos los app charts heredan exactamente el mismo endurecimiento: etiquetas idénticas, contextos de seguridad de pod y contenedor idénticos, y un resolutor de imágenes basado solo en digest que hace imposible publicar una imagen sin fijar.

<p align="center">
  <a href="https://quench-works.com"><img src="https://raw.githubusercontent.com/quenchworks/.github/main/profile/assets/demo.gif" alt="QuenchWorks en una terminal: ejecuta una imagen 0-CVE, verifícala con cosign, despliega el chart de Helm y observa cómo el pod llega a Running." width="760"></a>
</p>

Endurécelo una sola vez aquí, y cada chart del catálogo avanza en conjunto.

Se publica como un artefacto OCI y lo consumen los charts en [quenchworks/charts](https://github.com/quenchworks/charts):

```
oci://ghcr.io/quenchworks/charts/quench-common
```

## Cómo dependen de él los charts

```yaml
# Chart.yaml
dependencies:
  - name: quench-common
    version: 0.0.2
    repository: oci://ghcr.io/quenchworks/charts
```

## Qué proporciona

- **Nombres y etiquetas**: `quench-common.fullname` / `name` / `labels` / `selectorLabels`, consistentes en todo el catálogo.
- **El resolutor de imágenes basado solo en digest**: `quench-common.image` resuelve una imagen estrictamente mediante `repository@sha256:digest`. Una referencia basada solo en tag se rechaza a propósito, de modo que un chart nunca pueda publicar una imagen sin fijar.
- **Contexto de seguridad de pod endurecido**: `quench-common.podSecurityContext` establece `runAsNonRoot`, uid/gid/fsGroup 1001, seccomp `RuntimeDefault`.
- **Contexto de seguridad de contenedor endurecido**: `quench-common.containerSecurityContext` establece un sistema de archivos raíz de solo lectura, sin escalada de privilegios, descarta ALL capabilities.
- **Una superficie de ajustes compartida**: los puntos de override que cada chart expone de la misma manera, incluyendo planificación, probes, env/volumes/volumeMounts adicionales, init containers, sidecars, lifecycle hooks y overrides de contexto de seguridad.

## Versionado

Sube el `version` del chart con un patch en cada cambio, y nunca sobrescribas una versión publicada. Los app charts pasan entonces a la nueva versión en su siguiente publicación. Este es un library chart, así que no hay nada sobre lo que ejecutar `helm install` directamente.

## Release

Hacer push a `main` ejecuta `.github/workflows/release-common.yml`: lint, empaquetar, hacer push del chart OCI a GHCR y firmarlo con cosign (keyless).

## Licencia

MIT.
