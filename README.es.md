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
    version: 0.0.4
    repository: oci://ghcr.io/quenchworks/charts
```

## Qué proporciona

- **Nombres y etiquetas**: `quench-common.fullname` / `name` / `labels` / `selectorLabels`, consistentes en todo el catálogo.
- **El resolutor de imágenes basado solo en digest**: `quench-common.image` resuelve una imagen estrictamente mediante `repository@sha256:digest`. Una referencia basada solo en tag se rechaza a propósito, de modo que un chart nunca pueda publicar una imagen sin fijar.
- **Contexto de seguridad de pod endurecido**: `quench-common.podSecurityContext` establece `runAsNonRoot`, uid/gid/fsGroup 1001, seccomp `RuntimeDefault`.
- **Contexto de seguridad de contenedor endurecido**: `quench-common.containerSecurityContext` establece un sistema de archivos raíz de solo lectura, sin escalada de privilegios, descarta ALL capabilities.
- **Una superficie de ajustes compartida**: los puntos de override que cada chart expone de la misma manera, incluyendo planificación, probes, env/volumes/volumeMounts adicionales, init containers, sidecars, lifecycle hooks y overrides de contexto de seguridad.

### Objetos compartidos (0.0.3+)

Cinco familias de manifiestos que eran casi idénticas en cada chart ahora se generan aquí. Un chart adopta una con una sola línea, por ejemplo `templates/rbac.yaml` con `{{- include "quench-common.rbac" . }}`.

| helper | genera | se activa con |
| --- | --- | --- |
| `quench-common.ingress` | `Ingress` | `ingress.enabled` (**false por defecto**) |
| `quench-common.serviceAccount` | `ServiceAccount` | `serviceAccount.create` |
| `quench-common.rbac` | `Role` + `RoleBinding`, opcionalmente `ClusterRole` + `ClusterRoleBinding` | `rbac.create` |
| `quench-common.pdb` | `PodDisruptionBudget` | `podDisruptionBudget.enabled` |
| `quench-common.hpa` | `HorizontalPodAutoscaler` | `autoscaling.enabled` |
| `quench-common.networkPolicy` | `NetworkPolicy` | `networkPolicy.enabled` |

Qué manifiestos se movieron aquí se decidió midiendo el catálogo, no por gusto. Agrupando los 138 charts por forma generada: `serviceaccount.yaml` 117/132 idénticos, `poddisruptionbudget.yaml` 105/123, `rbac.yaml` 104/123, `hpa.yaml` 20/23. `networkpolicy.yaml` produjo 91 formas distintas porque cada aplicación permite puertos diferentes, así que su helper los toma de los values en lugar de fijarlos. `service.yaml` produjo 98 formas distintas de 128 charts y se queda deliberadamente en cada chart: la lista de puertos es la identidad de la aplicación, así que un helper necesitaría tanta configuración como el manifiesto que reemplaza.

Cada helper está pensado para ser sobrescrito, no para pelear con él:

- `extraLabels` y `annotations` en cada objeto.
- **Ingress**: múltiples hosts, `paths` por host (un host sin `paths` recibe un único `/` `Prefix`), `pathType`, lista TLS y `className` omitido por completo cuando no se define, para que aplique el predeterminado del clúster. El puerto de backend se resuelve desde `ingress.servicePort`, luego `service.port`, luego `service.ports.http` / `.https`, cubriendo las dos formas de service del catálogo. Se niega a generar un Ingress sin reglas y se niega a adivinar un puerto que no puede resolver.
- **RBAC**: `rbac.rules` (**vacío** por defecto, así nada se concede implícitamente), más `rbac.clusterScoped` con `rbac.clusterRules`. El nombre del `ClusterRoleBinding` incluye el namespace, porque los nombres de ámbito de clúster son globales y dos releases en namespaces distintos se disputarían un mismo objeto.
- **PDB**: `minAvailable` *o* `maxUnavailable`, `unhealthyPodEvictionPolicy`, o una sobrescritura completa de `spec`.
- **HPA**: `targetKind` / `targetName` (para que un chart StatefulSet pueda escalarse a sí mismo), `behavior`, objetivos de CPU y/o memoria, o una lista `metrics` totalmente personalizada.
- **NetworkPolicy**: `ingressPorts`, peers `extraFrom` (selector de namespace, ipBlock), listas completas de reglas `ingress` / `egress`, y `denyAllEgress`.

Ingress solo lo adoptan los charts que sirven HTTP. Un `Ingress` es un router HTTP, así que no puede ponerse delante de PostgreSQL, Redis, Kafka o etcd: expón esos con `service.type=LoadBalancer` o el passthrough TCP del controlador. Enviar un flag `ingress.enabled` que silenciosamente no hace nada sería peor que no tenerlo.

## Versionado

Sube el `version` del chart con un patch en cada cambio, y nunca sobrescribas una versión publicada. Los app charts pasan entonces a la nueva versión en su siguiente publicación. Este es un library chart, así que no hay nada sobre lo que ejecutar `helm install` directamente.

## Release

Hacer push a `main` ejecuta `.github/workflows/release-common.yml`: lint, empaquetar, hacer push del chart OCI a GHCR y firmarlo con cosign (keyless).

## Licencia

MIT.
